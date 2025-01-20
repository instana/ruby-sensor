require 'net/http'
require 'uri'
require 'json'

GEM_BUNDLE_PATH='/tmp/vendor/bundle'

class IbmCloudStorageUtil
  def upload_gem_bundle
    gzip_gem_bundle
    return unless has_different_gemsets?
    begin
      puts `echo "uploading gem set bundle"`
      uri = URI.parse(ENV["BUCKET_URL"]+"/#{ENV["TEST_SETUP"]}.tar.gz")
      request = Net::HTTP::Put.new(uri)
      request.content_type = "multipart/form-data"
      request["Authorization"] = "bearer #{get_token}"
      request.body = ""
      request.body << File.read(File.expand_path("#{ENV["TEST_SETUP"]}.tar.gz.new"))
      req_options = { use_ssl: uri.scheme == "https"}
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
      if response.kind_of?(Net::HTTPUnauthorized) || response.kind_of?(Net::HTTPForbidden)
        generate_token()
        upload(file_path)
      end
    rescue Errno::ENOENT => e
      puts "File matching the test setup not found. Fresh gem bundle will be installed"
    rescue
      return
    end
  end


  def download_gem_bundle
    begin
      puts "downloading the gem bundle"
      uri = URI.parse(ENV["BUCKET_URL"]+"/#{ENV["TEST_SETUP"]}.tar.gz")
      request = Net::HTTP::Get.new(uri)
      req_options = { use_ssl: uri.scheme == "https",
                      read_timeout: 120,
                      open_timeout: 120 }
      request["Authorization"] = "bearer #{get_token}"
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request) do |response|
          open "#{ENV["TEST_SETUP"]}.tar.gz", 'w' do |io|
            response.read_body do |chunk|
              io.write chunk
            end
          end
        end
      end
      if response.kind_of?(Net::HTTPUnauthorized) || response.kind_of?(Net::HTTPForbidden)
        generate_token()
        download(file_name)
      end
    rescue Errno::ENOENT => e
      generate_token()
      retry
    rescue
      return
    end
    unzip_gem_bundle
  end

  def gzip_gem_bundle
    puts "Compressing Gem Bundle ${TEST_SETUP}.tar.gz.new"
    `tar -czvf "${TEST_SETUP}.tar.gz.new" #{GEM_BUNDLE_PATH} ||  echo "failed compressing gem bundle"`
  end

  def unzip_gem_bundle
    puts "Decompressing Gem Bundle ${TEST_SETUP}.tar.gz"
    `tar -xzvf ${TEST_SETUP}.tar.gz -C '/' || echo "unzip of gem bundle failed"`
  end

  def generate_token
    uri = URI.parse(ENV["AUTHENTICATION_URL"])
    request = Net::HTTP::Post.new(uri)
    request.content_type = 'application/x-www-form-urlencoded'
    request.set_form_data({
    "apikey": ENV["API_KEY"],
    "response_type": "cloud_iam",
    "grant_type": "urn:ibm:params:oauth:grant-type:apikey"
    })
    req_options={
    use_ssl: uri.scheme == 'https'
    }
    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(request)
    end
    File.write("#{ENV["WORKSPACE_PATH"]}/token.txt", JSON.parse(response.body)["access_token"])
    return JSON.parse(response.body)
  end

  def get_token
    File.read("#{ENV["WORKSPACE_PATH"]}/token.txt")
  end

  def has_different_gemsets?
    output = `diff "#{ENV["TEST_SETUP"]}.tar.gz" "#{ENV["TEST_SETUP"]}.tar.gz.new"`
    puts "Gem bundle has not changed" unless output.include?("differ")
    puts output
    return output.include?("differ")
  end

end
