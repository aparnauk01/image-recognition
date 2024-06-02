locals {
  layer_zip_path    = "layer.zip"
  layer_name        = "image_recognition_lambda_requirements_layer"
  requirements_path = "${path.root}/env_image-recognition/requirements.txt"
}

resource "aws_s3_bucket" "image_bucket" {
  bucket = "apdev-image-rekognition-bucket"

  tags = {
    Name        = "Image"
    Environment = "Dev"
  }
}

resource "aws_lambda_permission" "s3_lambda_trigger_permission" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_recognition.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.image_bucket.arn
}

data "aws_iam_policy_document" "assume_role_recognition_lambda" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy" "lambda_logging_policy" {
  name = "function-logging-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Action : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect : "Allow",
        Resource : "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_rekognition_policy" {
  name = "function-rekognition-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Action : [
          "rekognition:*"
        ],
        Effect : "Allow",
        Resource : "*"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_s3_access_policy" {
  name = "lambda-S3-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Action : [
          "s3:GetObject",
          "s3:PutObject"
        ],
        Effect : "Allow",
        Resource : "arn:aws:s3:::{aws_s3_bucket.image_bucket}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "s3_bucket_policy_for_rekognition" {
  bucket = aws_s3_bucket.image_bucket.id
  policy = data.aws_iam_policy_document.s3_bucket_policy_for_rekognition.json
}

data "aws_iam_policy_document" "s3_bucket_policy_for_rekognition" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["rekognition.amazonaws.com"]
    }

    actions = [
      "s3:*"
    ]

    resources = [
      aws_s3_bucket.image_bucket.arn,
      "${aws_s3_bucket.image_bucket.arn}/*",
    ]
  }
}

resource "aws_iam_role" "iam_for_image_recognition_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role_recognition_lambda.json
}

resource "aws_iam_role_policy_attachment" "function_logging_policy_attachment" {
  role       = aws_iam_role.iam_for_image_recognition_lambda.id
  policy_arn = aws_iam_policy.lambda_logging_policy.arn
}

resource "aws_iam_role_policy_attachment" "function_rekognition_policy_attachment" {
  role       = aws_iam_role.iam_for_image_recognition_lambda.id
  policy_arn = aws_iam_policy.lambda_rekognition_policy.arn
}

resource "aws_iam_role_policy_attachment" "function_s3_policy_attachment" {
  role       = aws_iam_role.iam_for_image_recognition_lambda.id
  policy_arn = aws_iam_policy.lambda_s3_access_policy.arn
}


resource "aws_cloudwatch_log_group" "image_recognition_lambda_log_group" {
  name              = "/aws/lambda/image-recognition"
  retention_in_days = 7
  lifecycle {
    prevent_destroy = false
  }
}

data "archive_file" "image_recognition" {
  type        = "zip"
  source_file = "${path.module}/code/lambda_function.py"
  output_path = "lambda_function_zip.zip"
}

# data "archive_file" "image_recognition_layers" {
#   type        = "zip"
#   source_file = "${path.module}/layers/requirements.txt" 
#   output_path = "image_recognition_lambda_layer.zip"
# }

resource "aws_lambda_function" "image_recognition" {
  filename         = "lambda_function_zip.zip"
  function_name    = var.function_name
  role             = aws_iam_role.iam_for_image_recognition_lambda.arn
  handler          = "lambda_function.lambda_handler"
  depends_on       = [aws_cloudwatch_log_group.image_recognition_lambda_log_group, null_resource.lambda_layer]
  source_code_hash = data.archive_file.image_recognition.output_base64sha256
  runtime          = var.runtime
  layers = [aws_lambda_layer_version.buesiness_rule_lambda_layer.arn]
}

resource "aws_s3_bucket_notification" "image_recognition_trigger" {
  bucket = aws_s3_bucket.image_bucket.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.image_recognition.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.s3_lambda_trigger_permission]
}

resource "null_resource" "lambda_layer" {
  triggers = {
    requirements = filesha1(local.requirements_path)
  }
  # the command to install python and dependencies to the machine and zips
  provisioner "local-exec" {
    command = <<EOT
        echo "creating layers with requirements.txt packages..."

        cd ${path.root}
        # rm -rf ${var.dir_name}
        mkdir ${var.dir_name}

        # Create and activate virtual environment...
        virtualenv -p ${var.runtime} env_${var.function_name}
        source ${path.cwd}/env_${var.function_name}/bin/activate

        # Installing python dependencies...
        if [ -f ${local.requirements_path} ]; then
            echo "From: requirement.txt file exists..."  

            pip install -r ${local.requirements_path} -t ${var.dir_name}/
            zip -r ${local.layer_zip_path} ${var.dir_name}/
         else
            echo "Error: requirement.txt does not exist!"
        fi

        # Deactivate virtual environment...
        deactivate

        #deleting the python dist package modules
        rm -rf ${var.dir_name}
        
    EOT
  }
}


data "aws_s3_bucket" "layer_bucket" {
  bucket = var.lambda_layer_bucket
}

# upload zip file to s3
resource "aws_s3_object" "lambda_layer_zip" {
  bucket     = data.aws_s3_bucket.layer_bucket.id
  key        = "lambda_layers/${local.layer_name}/${local.layer_zip_path}"
  source     = local.layer_zip_path
  depends_on = [null_resource.lambda_layer] # triggered only if the zip file is created
}

# create lambda layer from s3 object
resource "aws_lambda_layer_version" "buesiness_rule_lambda_layer" {
  s3_bucket           = data.aws_s3_bucket.layer_bucket.id
  s3_key              = aws_s3_object.lambda_layer_zip.key
  layer_name          = local.layer_name
  compatible_runtimes = ["${var.runtime}"]
  skip_destroy        = true
  depends_on          = [aws_s3_object.lambda_layer_zip] # triggered only if the zip file is uploaded to the bucket
}