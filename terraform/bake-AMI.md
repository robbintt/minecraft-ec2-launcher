# Baking an AMI


## Manual Setup (move to ansible)



To make am image, do the following.

1. Create an EC2 instance
  - Select Amazon Linux 2
  - specify the correct image hard drive size.

2. Login to the instance and secure copy the following (could symlink from efs in the future)
  - minecraft@.service

3. Connect the minecraft EFS (elastic fileesystem)
  1. Install aws linux efs tools: `sudo yum install -y amazon-efs-utils`
    - from: https://docs.aws.amazon.com/efs/latest/ug/using-amazon-efs-utils.html#installing-amazon-efs-utils
  2. make the mountpoint: `sudo mkdir /mnt/efs/`
  2. add it to fstab: `"sudo bash -c "echo \"fs-dbe70e5a:/ /mnt/efs efs defaults,_netdev 0 0\" >> /etc/fstab"`
  3. next, mount it: `sudo mount -a`
    - check the user permissions to see that your user can read from everything

4. Symlink ~/minecraft as /mnt/efs/minecraft
  - efs minecraft links to world, although it could just have world inside minecraft now...

5. enable autoshutdown detector and crontab
  - `sudo systemctl start crontab`
  - `sudo systemctl enable crontab`
  - `crontab -e`
    - `*/1 * * * * cd /mnt/efs/minecraft && ./detect_empty_server > /dev/null`

6. Set up & Start the minecraft@service
  - Make sure no one else is using the efs!
  - install java: sudo yum install -y java-1.8.0
  - move the service: `mv minecraft@.service /etc/systemd/system/`
  - enable the service: `sudo systemctl enable minecraft@1`
  - start the service: `$ sudo systemctl start minecraft@1`

7. set up monitoring services as needed
  - sudy yum install -y htop
