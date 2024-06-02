variable "function_name" {
  default = "image-recognition"
  type    = string

}

variable "dir_name" {
  default = "layers"
  type    = string
}

variable "runtime" {
  default = "python3.11"
  type    = string

}

variable "lambda_layer_bucket" {
    default ="image-recognition-lambda-layer"
    type = string
  
}