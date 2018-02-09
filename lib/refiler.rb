require File.join('.', 'lib', 'errorable')
require 'json'

class Refiler
  include Errorable

  # options is a hash used to instantiate a Refiler
  #  options barcodes [Array of strings]
  #  options nypl_platform_client [NyplPlatformClient]
  def initialize(options = {})
    @errors = {}
    @barcodes = options[:barcodes]
    @nypl_platform_client = options[:nypl_platform_client]
  end

  def refile!
    @barcodes.each do |barcode|
      begin
        response = @nypl_platform_client.refile(barcode)
        if response.code >= 400
          add_or_append_to_errors(barcode, JSON.parse(response.body['message']))
        end
      rescue Exception => e
        add_or_append_to_errors(barcode, 'Bad response from NYPL refile API')
      end
    end
  end

end
