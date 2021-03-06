require File.join(__dir__, '..', 'boot')
require File.join('.', 'lib', 'errorable')

class SubmitCollectionUpdater

  include Errorable

  # options is a hash used to instantiate a SubmitCollectionUpdater
  #  options api_key [String]
  #  options api_url [String]
  #  options is_gcd_protected [Boolean]
  #  options barcode_to_scsb_xml_mapping [Hash]
  #    This is the output of SCSBXMLFetchertranslate_to_scsb_xml
  #  options is_dry_run [String]
  def initialize(options = {})
    @errors = {}
    @barcode_to_scsb_xml_mapping = options[:barcode_to_scsb_xml_mapping]
    @api_url  = options[:api_url]
    @api_key = options[:api_key]
    @is_gcd_protected = options[:is_gcd_protected] || false
    @is_dry_run = options[:is_dry_run]
    @logger = Application.logger
  end

  def update_scsb_items
    if (@is_dry_run)
      puts "This is a dry run for development. It will not update any SCSB collection item."
    else
      puts "Updating the following #{@barcode_to_scsb_xml_mapping.keys.length} barcodes: #{@barcode_to_scsb_xml_mapping.keys.join(',')}"
      @barcode_to_scsb_xml_mapping.each do |barcode, scsb_xml|
        # it stops calling the API to update the record if no valid XML
        if scsb_xml.empty?
          add_or_append_to_errors(barcode, 'did not not have valid SCSB XML, which will prevent record being submitted')
          @logger.error("No valid XML for the barcode: #{barcode}. It has stopped updating the record.")
        else
          update_item(barcode, scsb_xml)
        end
      end
    end
  end

private

  def headers
    {
      Accept: 'application/json',
      api_key: @api_key,
      "Content-Type": 'application/json'
    }
  end

  def update_item(barcode, scsb_xml)
    begin
      # Remove <xml version=... tag
      stripped_doc = Nokogiri::XML(scsb_xml).root.to_s
      response = HTTParty.post("#{@api_url}/sharedCollection/submitCollection", headers: headers, body: stripped_doc, query: {institution: 'NYPL', isCGDProtected: @is_gcd_protected})
      parsed_body = JSON.parse(response.body)

      if parsed_body[0] && parsed_body[0]['message'] && !parsed_body[0]['message'].downcase.include?('success')
        @logger.warn("problem response from SCSB submitCollection for barcode #{barcode}: #{parsed_body[0]['message']}")
        add_or_append_to_errors(barcode, parsed_body[0]['message'])
      end

      puts "sent barcode #{barcode} to submitCollection. The response was #{response.body}"
    rescue Exception => e
      @logger.error("Barcode #{barcode} received a bad response from SCSB /sharedCollection/submitCollection API: #{e.message}")
      add_or_append_to_errors(barcode, 'received a bad response from SCSB /sharedCollection/submitCollection API')
    end
  end

end
