## basic EC2 instance

Create a private key or using an existing key to bake into the ec2 instance. Here we're importing an existing key to AWS. We'll refer the to key name in our main.tf

```aws ec2 import-key-pair --key-name priv --public-key-material fileb://priv.pub```

