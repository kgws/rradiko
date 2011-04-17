# -*- coding: utf-8; -*-
# Author::    kgws  (http://d.hatena.ne.jp/kgws/)
# Copyright:: Copyright (c) 2010- kgws.
# License::   This program is licenced under the same licence as kgws.
#
# $--- RRadiko - [ by Ruby ] $
# vim: foldmethod=marker tabstop=2 shiftwidth=2 autoindent
$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))
require 'logger'
require 'optparse'
require 'net/http'
require 'rexml/document'
require 'rradiko/core'

$KCODE = 'UTF-8' if RUBY_VERSION < '1.9'

module Rradiko
  VERSION = '0.0.1'
end
