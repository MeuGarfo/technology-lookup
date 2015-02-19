require "curl"
require "timeout"

module Frameworks
  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.11 (KHTML, like Gecko) Chrome/23.0.1271.97 Safari/537.11"
  PARALLEL_REQUESTS = 50
  TIMEOUT = 10
  FRAMEWORK_MATCHERS = {
    "ruby/rack" => [
      /X-Rack-Cache:/i,
      /X-Powered-By:.*(Passenger|Mongrel)/i,
      /Server:\s+Mongrel/
    ],
    "ruby" => [
      /Server: .*mod_ruby/i,
      /Server: thin/i
    ],
    "php/symfony" => [
      /Set-Cookie:\s+symfony/i
    ],
    "php/codeigniter" => [
      /Set-Cookie:\sci_session.*/i
    ],
    "php/wordpress" => [
      /Server:\s+WP Engine/i,
      /WP-Super-Cache:.*/i,
      /X-Powered-By:\sW3 Total Cache.*/i,
      /X-CF-Powered-By:\sWP .*/i
    ],
    "php" => [
      /Set-Cookie:\s+PHPSESSID=/i,
      /X-Powered-By:\s+PHP\//i
    ],
    "asp" => [
      /Set-Cookie:\s+ASP.NET_SessionId=/i,
      /X-Powered-By:\s+ASP.NET/i,
      /X-AspNetMvc-Version:/i
    ],
    "java" => [
      /Set-Cookie:\s+JSESSIONID=/i,
      /Server:\s+Jetty/i,
      /Server:\sApache-Coyote/i
    ],
    "ruby/rails" => [
      /Set-Cookie:\s+_[a-zA-Z0-9.-_]+_session/i
    ],
    "python/tornado" => [
      /Server:\s+TornadoServer/i
    ],
    "python" => [
      /Server:\s+gunicorn/i,
      /Set-Cookie:\s+webpy_session_id/i
    ],
    "python/django" => [
      /Set-Cookie:\s+django_/i,
      /Set-Cookie:\s+csrftoken=/i
    ],
    "node" => [
      /X-Powered-By:\s+Express/i,
      /Set-Cookie:\s+connect.sid=/i
    ],
    "scala/play" => [
      /Server:\s+Play! Framework/i,
      /Set-Cookie:\s+PLAY_SESSION/i
    ],
    "perl/dancer" => [
      /X-Powered-By:\s+Perl Dancer/i
    ],
    "appengine" => [
      /Server:\s+Google Frontend/i
    ],
    "static/s3" => [
      /Server:\s+AmazonS3/i
    ],
    "_session_id (rails2?)" => [
      /Set-Cookie:\s+_session_id=/
    ]
  }

  def self.get_headers_for_domains(domains)
    headers = {}

    easy_options = {:follow_location => true}
    multi_options = {:pipeline => true}

    m = Curl::Multi.new
    domains.each do |url|
      url = "http://#{url}" unless url =~ /\Ahttps?:\/\//

      headers[url] = ""
      c = Curl::Easy.new(url) do |curl|
        curl.follow_location = true
        curl.head = true
        curl.timeout = TIMEOUT
        curl.useragent = USER_AGENT

        curl.on_header do |data|
          headers[url] << data
          data.size
        end
      end
      m.add(c)
    end

    begin
      Timeout::timeout(60) { m.perform }
    rescue Timeout::Error
      $stderr.puts "Batch timed out"
    end

    headers
  end

  def self.find_framework_from_headers(headers)
    return :failed if headers.nil? || headers.strip.empty?

    FRAMEWORK_MATCHERS.each do |tech, regexes|
      regexes.each do |r|
        if headers.match(r)
          return tech
        end
      end
    end

    return :unknown
  end

  def self.get_framework_for_domains(domains)
    frameworks = {}
    domains.each_slice(PARALLEL_REQUESTS) do |slice|
      headers = get_headers_for_domains(slice)
      headers.each do |domain, headers|
        framework = find_framework_from_headers(headers)
        frameworks[domain] = framework
        yield(domain, framework) if block_given?
      end
    end

    frameworks
  end
end
