module Rradiko
  BASE_PATH = File.expand_path("~")
  AREA_LIST = [
    'JP13',
    'JP27',
  ]
  TOKYO_CHANNEL_LIST = [
    'TBS',
    'QRR',
    'LFR',
    'NSB',
    'INT',
    'FMT',
    'FMJ',
  ]
  OSAKA_CHANNEL_LIST = [
    '802',
    'FMO',
    'ABC',
    'CCL',
    'OBC',
    'MBS',
  ]
  CHANNEL_LIST = {
    'TBS' => "TBSラジオ",
    'QRR' => "文化放送",
    'LFR' => "ニッポン放送",
    'NSB' => "ラジオNIKKEI",
    'INT' => "Inter FM",
    'FMT' => "FM Tokyo",
    'FMJ' => "J-Wave",
    '802' => "FM-802",
    'FMO' => "FM-OSAKA",
    'ABC' => "朝日放送ラジオ",
    'CCL' => "FM-CoCoRo",
    'OBC' => "ラジオ大阪",
    'MBS' => "毎日放送ラジオ",
  }
class Rradiko
  # {{{ initialize
  def initialize
    @schedule = {
      :flag    => false,
      :area    => 'tokyo',
      :date    => 'today',
      :channel => nil,
    }
    @change_mp3 = true
    @rtmpdump_cmd = `which rtmpdump`.strip!
    @rtmpdump_option = "-q -f \"LNX 10,0,45,2\" -s http://radiko.jp/player/player_0.0.8.swf"
    @ffmpeg_cmd = `which ffmpeg`.strip!
    @ffmpeg_option = "-y"
    @data_dir = BASE_PATH
    @time
    @channel
    @title = "NO_TITLE"
    @download_retry = 30
    @log = {
      :flag => false,
      :path => "/var/log/rradiko.log",
      :age  => 0,
      :size =>1048576,
    }
    if @log[:flag]
      @logger = Logger.new(STDOUT)
    else
      @logger = Logger.new(@log[:path], @log[:age], @log[:size])
    end
    @opt = OptionParser.new
    self.opt_parse
    if $DEBUG
      @logger.level = Logger::DEBUG
    else
      @logger.level = Logger::WARN
    end

    if @schedule[:flag]
      self.schedule_list
      exit(0)
    end
    if @time.nil? || @channel.nil?
      @logger.error("Please set the recording time. --time=TIME (min.)") if @time.nil?
      @logger.error("Please set the channel. --channel=CHANNEL") if @channel.nil?
      exit(1)
    end
  end
  # }}}
  # {{{ opt_parse
  def opt_parse
    @opt.version = VERSION
    @opt.on('-d',         '--debug',                     "debug mode on"){$DEBUG = true}
    @opt.on('-t=TIME',    '--time=TIME',                 "recording time (min.)"){|v| @time = v.to_i}
    @opt.on('-c=CHANNEL', '--channel=CHANNEL',           "channel"){|v| @channel = v}
    @opt.on(              '--channel-show',              "channel list show"){CHANNEL_LIST.each {|v,k| puts "#{v}: #{k}"} ; exit(0)}
    @opt.on(              '--tokyo-schedule=[CHANNEL]',  "radio schedule in Tokyo"){|v| @schedule[:flag] = true ; @schedule[:area] = 'tokyo' ; @schedule[:channel] = v if v}
    @opt.on(              '--osaka-schedule=[CHANNEL]',  "radio schedule in Osaka"){|v| @schedule[:flag] = true ; @schedule[:area] = 'osaka' ; @schedule[:channel] = v if v}
    @opt.on(              '--tomorrow',                  "tomorrow's radio show"){@schedule[:date] = 'tomorrow'}
    @opt.on(              '--title=[TITLE]',             "program title (default: #{@title})"){|v| @title = v}
    @opt.on(              '--[no-]change-mp3',           "skip change mp3 file"){|v| @change_mp3 = v}
    @opt.on(              '--directory=[DIRECTORY]',     "save directory (default: #{@data_dir})"){|v| @data_dir = v}
    @opt.on(              '--logger',                    "logger mode on"){@log[:flag] = true}
    @opt.on(              '--logger-path=[PATH]',        "log file path (default: #{@log[:path]})"){|v| @log[:path] = v}
    @opt.on(              '--logger-age=[AGE]',          "log file age (default: #{@log[:age]})"){|v| @log[:age] = v}
    @opt.on(              '--logger-size=[SIZE]',        "log file size (default: #{@log[:size]})"){|v| @log[:size] = v}
    begin
      @opt.parse!(ARGV)
    rescue OptionParser::ParseError => err
      puts err.message
      puts @opt.to_s
      exit(1)
    end
  end
  # }}}
  # {{{ error
  def error(msg)
    puts "\033[31m[ERROR]\033[m #{msg}"
  end
  # }}}
  # {{{ shellesc
  def shellesc(str, opt={})
    str = str.dup
    if opt[:erace]
      opt[:erace] = [opt[:erace]] unless Array === opt[:erace]
      opt[:erace].each do |i|
        case i
        when :ctrl   then str.gsub!(/[\x00-\x08\x0a-\x1f\x7f]/, '')
        when :hyphen then str.gsub!(/^-+/, '')
        else              str.gsub!(i, '')
        end
      end
    end
    str.gsub!(/[\!\"\$\&\'\(\)\*\,\:\;\<\=\>\?\[\\\]\^\`\{\|\}\t ]/, '\\\\\\&')
    str
  end
  # }}}
  # {{{ command
  def command(cmd)
    @logger.info "command=[#{cmd}]"
    if $DEBUG
      res = true
    else
      res = system(cmd)
    end
    res
  end
  # }}}
  def wget(host, path ,port=80)
    @logger.debug("wget url http://#{host}:#{port}#{path}")
    res = false
    Net::HTTP.start(host, port) do |http|
      res = http.get(path)
    end
    res.body
  rescue
    false
  end
  # {{{ get_schedule
  def get_schedule(area_id, mode)
    host = 'radiko.jp'
    path = "/epg/newepg/epgapi.php?area_id=%s&mode=%s" % [area_id, mode]
    res = {}
    data = self.wget(host, path)
    xmldoc = REXML::Document.new(data)
    xmldoc.elements.each("//station()") do |station|
      station_id = station.attribute('id').to_s
      res[station_id] = {}
      res[station_id]["station_name"] = station.elements["scd/name"].text.to_s
      res[station_id]["date"] = station.elements["scd/progs"].attribute('date').to_s
      res[station_id]["progs"] = []
      station.elements.each("scd/progs/prog") do |prog|
        tmp = {}
        tmp["title"] = prog.elements["title"].text
        tmp["start_time"] = prog.attributes["ftl"]
        tmp["end_time"] = prog.attributes["tol"]
        res[station_id]["progs"] << tmp
      end
    end
    res
  end
  # }}}
  # {{{ show_schedule
  def show_schedule(station_name, date, progs)
    date = Time.local(date[0..3], date[4..5], date[6..7], 0, 0, 0)
    puts "%s - (%s/%s/%s %s)" % [station_name, date.year, date.month, date.day, date.strftime("%a")]
    progs.each do |prog|
      puts "  %2s:%2s-%2s:%2s %s" % [prog["start_time"][0..1], prog["start_time"][2..3],  prog["end_time"][0..1], prog["end_time"][2..3], prog["title"]]
    end
  end
  # }}}
  # {{{ schedule_list
  def schedule_list
    area_id = ""
    channel_list = []
    if @schedule[:area] == 'tokyo'
      channel_list = TOKYO_CHANNEL_LIST
      area_id = 'JP13'
    elsif @schedule[:area] == 'osaka'
      channel_list = OSAKA_CHANNEL_LIST
      area_id = 'JP27'
    else
      @logger.error("Not' found area #{@schedule[:channel]}")
      exit(1)
    end

    unless  @schedule[:date] == 'today' ||  @schedule[:date] == 'tomorrow'
      @logger.error("today or tomorrow")
      exit(1);
    end
    schedule = self.get_schedule(area_id, @schedule[:date])
    if @schedule[:channel] && channel_list.include?(@schedule[:channel])
      self.show_schedule(schedule[@schedule[:channel]]['station_name'], schedule[@schedule[:channel]]['date'],schedule[@schedule[:channel]]['progs'])
    else
      channel_list.each do |channel|
        self.show_schedule(schedule[channel]['station_name'], schedule[channel]['date'], schedule[channel]['progs'])
      end
    end
  end
  # }}}
  # {{{ execute
  def execute
    @logger.info "#{@title} start"
    @logger.info "#{@title} directory=[#{@data_dir}]"
    date = Time.new.strftime("%Y%m%d%H%M")
    @logger.info "#{@title} date=[#{date}]"
    time = @time * 60
    @logger.info "#{@title} time=[#{@time}min. #{time}sec.]"
    title = "#{@title}_#{date}"
    @logger.info "#{@title} title=[#{title}]"
    flv_file = File.join(@data_dir, "#{title}.flv")
    mp3_file = File.join(@data_dir, "#{title}.mp3")

    # stream download
    count = 1
    @logger.info "#{@title} stream download"
    begin
      if count > 1
        sleep_time = count * 2
        @logger.info("sleep... sleep_time=[#{sleep_time}] count=[#{count}] title=[#{@title}]")
        time = time - sleep_time
        sleep sleep_time
      end
      cmd = "#{@rtmpdump_cmd} #{@rtmpdump_option} -vr rtmpe://radiko.smartstream.ne.jp/#{@channel}/_defInst_/simul-stream -o "+ self.shellesc(flv_file) + " -B #{time}"
      res = self.command(cmd)
      if res === true
        @logger.info("download successfully. title=[#{@title}]")
      else
        @logger.error("download failed. title=[#{@title}] res=[#{res}] count=[#{count}]")
      end
      if count >= @download_retry
        @logger.error("gave up downloading. title=[#{@title}] count=[#{count}]")
        exit(1)
      end
      count += 1
    end until res

    # encode mp3
    if @change_mp3 === true
      @logger.info "#{@title} change mp3"
      cmd = "#{@ffmpeg_cmd} #{@ffmpeg_option} -i "+ self.shellesc(flv_file) + " -acodec libmp3lame "+ self.shellesc(mp3_file)
      res = self.command(cmd)

      unless $DEBUG
        # remove flv file
        @logger.info "#{@title} remove flv file file=[#{flv_file}]"
        File.unlink(flv_file)
      end
    end
    @logger.info "#{@title} end"
    rescue
      @logger.error($!)
  end
  # }}}
end
end

