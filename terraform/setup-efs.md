# Setting up EFS

1. Create EFS IA filesystem
2. Update the mountpoint in your AMI `/etc/fstab` to the new `File System ID`

3. Put world in efs
4. Put minecraft files into efs
  - specify the world foldername in minecraft settings file
  - symlink the world into the minecraft directory
5. Add additional files
  - detect-empty-server 
    - add to the minecraft directory and it will be picked up by existing AMI cron
