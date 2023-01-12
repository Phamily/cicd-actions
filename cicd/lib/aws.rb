class AwsModule

  def prepare
    set :aws_access_key, ENV['INPUT_AWS_ACCESS_KEY']
    set :aws_secret_access_key, ENV['INPUT_AWS_SECRET_ACCESS_KEY']
    set :aws_region, ENV['INPUT_AWS_REGION']

    aws_ak = fetch(:aws_access_key)
    aws_sak = fetch(:aws_secret_access_key)
    aws_reg = fetch(:aws_region)
    return if !present?(aws_ak)
    puts "Configuring AWS Credentials."
    # write aws config
    sh "mkdir -p #{ENV['HOME']}/.aws"
    File.write "#{ENV['HOME']}/.aws/credentials", "[default]\naws_access_key_id = #{aws_ak}\naws_secret_access_key = #{aws_sak}\n"
    File.write "#{ENV['HOME']}/.aws/config", "[default]\nregion = #{aws_reg}\noutput = json\n"
  end

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