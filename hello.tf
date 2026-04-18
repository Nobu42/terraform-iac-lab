# hello.tf
resource "terraform_data" "sample" {
  provisioner "local-exec" {
    command = "echo \"Hello, Terraform.\""
  }
}
