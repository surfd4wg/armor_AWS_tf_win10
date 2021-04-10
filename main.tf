# Specify the provider and access details
provider "aws" {
  region = var.aws_region
  access_key = var.access_key
  secret_key = var.secret_key
}

# Lookup the correct AMI based on the region specified
data "aws_ami" "amazon_windows_10_hacked" {
  most_recent = true
  owners      = ["474819473469"]

  filter {
    name   = "name"
    values = ["Windows10*"]
  }

}

resource "aws_instance" "winrm" {
  # The connection block tells our provisioner how to
  # communicate with the resource (instance) using WinRM
    get_password_data = true
    connection {
      host = self.public_ip
      type     = "winrm"
      user     = "Administrator"
     private_key = file(var.private_key_path)
    timeout = "10m"
    }

  # Change instance type for appropriate use case
    instance_type = "t2.medium"
 
  #ami    
  #  ami = "ami-056f139b85f494248"
  # ami = "ami-04c7f5a0e4cc067e0"
  ami = data.aws_ami.amazon_windows_10_hacked.image_id
  # Root storage
  # Terraform doesn't allow encryption of root at this time
  # encrypt volume after deployment.
  root_block_device {
    volume_type = "gp2"
    volume_size = 50
    delete_on_termination = true
  }

  # AZ to launch in
  availability_zone = var.aws_availzone

  # VPC subnet and SGs
  subnet_id = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.allowall.id]
  associate_public_ip_address = "true"

  # The number of instances to spin up
  count = var.instance_count
  # The name of our SSH keypair you've created and downloaded
  # from the AWS console.
  #
  # https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#KeyPairs
  #
  key_name = var.key_name
#  admin_password_base = aws_instance.winrm.*.password_data

# Ec2 user data, WinRM and PowerShell Provision Functions
   user_data = <<EOF
	<powershell>
        #rename computer
                Rename-Computer -newname "hacked-Windows10-Terraform-${count.index + 1}"

	#Allow All TLS versions 
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12, [Net.SecurityProtocolType]::Ssl3
		[Net.ServicePointManager]::SecurityProtocol = "Tls, Tls11, Tls12, Ssl3"

	#Windows Remoting
		net user ${var.INSTANCE_USERNAME} '${var.INSTANCE_PASSWORD}' /add /y
		net localgroup administrators ${var.INSTANCE_USERNAME} /add
		winrm quickconfig -q
		winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="300"}'
		winrm set winrm/config '@{MaxTimeoutms="1800000"}'
		winrm set winrm/config/service '@{AllowUnencrypted="true"}'
		winrm set winrm/config/service/auth '@{Basic="true"}'
		netsh advfirewall firewall add rule name="WinRM 5985" protocol=TCP dir=in localport=5985 action=allow
		netsh advfirewall firewall add rule name="WinRM 5986" protocol=TCP dir=in localport=5986 action=allow
		net stop winrm
		sc.exe config winrm start=auto
		net start winrm

	#Chrome
		$LocalTempDir = $env:TEMP; $ChromeInstaller = "ChromeInstaller.exe"; (new-object System.Net.WebClient).DownloadFile('http://dl.google.com/chrome/install/375.126/chrome_installer.exe', "$LocalTempDir\$ChromeInstaller"); & "$LocalTempDir\$ChromeInstaller" /silent /install; $Process2Monitor =  "ChromeInstaller"; Do { $ProcessesFound = Get-Process | ?{$Process2Monitor -contains $_.Name} | Select-Object -ExpandProperty Name; If ($ProcessesFound) { "Still running: $($ProcessesFound -join ', ')" | Write-Host; Start-Sleep -Seconds 2 } else { rm "$LocalTempDir\$ChromeInstaller" -ErrorAction SilentlyContinue -Verbose } } Until (!$ProcessesFound)

	#IIS
		Install-WindowsFeature -name Web-Server -IncludeManagementTools
		#Invoke-WebRequest https://armorscripts.s3.amazonaws.com/WINscripts/WIN2012R2std.jpg -outfile c:\inetpub\wwwroot\WIN2012R2std.jpg
		#Invoke-WebRequest https://armorscripts.s3.amazonaws.com/WINscripts/iisstart2012R2.htm -outfile c:\inetpub\wwwroot\iisstart.htm

	#ssh
		mkdir c:\OpenSSH
		cd c:\OpenSSH
		Invoke-WebRequest https://armorscripts.s3.amazonaws.com/sshinstall.ps1 -outfile sshinstall.ps1 
		.\sshinstall.ps1

	#Armor Agent
		mkdir c:\armorinstall
		cd c:\armorinstall
		Invoke-WebRequest https://agent.armor.com/latest/armor_agent.ps1 -outfile c:\armorinstall\armor_agent.ps1
		New-Item -Path . -Name "armorinstall.ps1" -ItemType "file" -Value ".\armor_agent.ps1 -license ${var.ARMKEY} -region us-west-armor -full"
		.\armorinstall.ps1

        #mal-files
                Invoke-WebRequest https://armorscripts.s3.amazonaws.com/EICARfiles/eicar_com.zip -outfile c:\inetpub\wwwroot\eicar_com.zip
                Invoke-WebRequest https://armorscripts.s3.amazonaws.com/EICARfiles/eicar.com -outfile c:\inetpub\wwwroot\eicar.com
                Invoke-WebRequest https://armorscripts.s3.amazonaws.com/EICARfiles/eicar.com.txt -outfile c:\inetpub\wwwroot\eicar.com.txt
                Invoke-WebRequest https://armorscripts.s3.amazonaws.com/EICARfiles/eicarcom2.zip -outfile c:\inetpub\wwwroot\eicarcom2.zip
                Invoke-WebRequest https://armorscripts.s3.amazonaws.com/HACKEDby/innocentfile_hacked_by.html -outfile c:\inetpub\wwwroot\iisstart.htm
#               Invoke-WebRequest https://armorscripts.s3.amazonaws.com/WINscripts/POWERshellSKULLax.ps1 -outfile c:\Users\Administrator\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
#               Invoke-WebRequest https://armorscripts.s3.amazonaws.com/WINscripts/POWERshellSKULLax.ps1 -outfile c:\Users\Administrator\Documents\WindowsPowerShell\profile.ps1
                Invoke-WebRequest https://armorscripts.s3.amazonaws.com/WINscripts/POWERshellSKULLax.ps1 -outfile c:\Windows\System32\WindowsPowerShell\v1.0\profile.ps1
#               Invoke-WebRequest https://armorscripts.s3.amazonaws.com/WINscripts/POWERshellSKULLax.ps1 -outfile c:\Windows\System32\WindowsPowerShell\v1.0\Microsoft.PowerShell_profile.ps1
                c:\Windows\System32\WindowsPowerShelv1.0\profile.ps1


	</powershell>
	EOF

	tags = {
		#Name = var.instance_name
		Name = "hacked-Windows10-Terraform-${count.index + 1}"
	}

}
