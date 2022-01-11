class LambdaModule

  def prepare
    set :lambda_function_name, ENV['INPUT_LAMBDA_FUNCTION_NAME']
  end

  def deploy
    lfn = fetch(:lambda_function_name)
    iuri = full_remote_image_name
    sh "aws lambda update-function-code --region #{fetch(:aws_region)} --function-name #{lfn} --image-uri #{iuri}"
  end

end