#!/usr/bin/env ruby

require "sinatra"
require "slim"
require "./frameworks"

get "/" do
  slim :index
end

post "/lookup" do
  domain_array = params[:urls].split("\n").map {|d| d.strip }
  @results = Frameworks.get_framework_for_domains(domain_array)

  slim :results
end
