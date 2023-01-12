class AwsModule

  def update_dns_record(opts={})
    host = opts[:host]
    rtype = opts[:type]
    rvalue = opts[:value]
    change = <<~JSON
    {
      "Comment": "Update DNS record for sub domain",
      "Changes": [
          {
              "Action": "UPSERT",
              "ResourceRecordSet": {
                  "Name": #{host},
                  "Type": #{type},
                  "TTL": 300,
                  "ResourceRecords": [
                      {
                          "Value": #{rvalue}
                      }
                  ]
              }
          }
      ]
    }
    JSON
    change_file_path = write_tmp_file(change, ".json")
    puts "Updating DNS settings for #{host}"


    zone = get_hosted_zone_for_host(host)
    zone_id = zone["Id"]
    sh "aws route53 change-resource-record-sets --hosted-zone-id #{zone_id} --change-batch file://#{change_file_path}"
  end

  private

  def get_hosted_zones
    json = `aws route53 list-hosted-zones`
    JSON.parse(json)["HostedZones"]
  end

  def get_hosted_zone_for_host(host)
    zones = get_hosted_zones
    zones.select {|z| z["Name"].include?(host)}.first
  end

end