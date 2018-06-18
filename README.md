# PolySwarm Hive

This project is for the easy setup of a PolySwarm test/dev network on
DigitalOcean. 

To run, you need to first get a token from DigitalOcean's website. After
grabbing it, store it in a file called `token` in the root of this project. The
script uses that token to create the cURL commands that will create the doplets.

In addition, you need to add some ssh keys to the website. When you create an
ssh key, grab the id for the ssh key, and put in into a file called `key`. This
will tell it what ssh key to add to the droplets so that someone can ssh in and
configure them further if need be (Like adding valid ssh keys to let devs access
the hive).

# What it creates

This will open two droplets. The first is an ssh hop. Users need to ssh to our
box, or transparently connect through to the next box. The second is running
polyswarmd, geth and ipfs. polyswarmd is running on 31337 and will allow a user
to create, read, and modify bounties/assertions on the test PolySwarm network. 

IPFS is running on port 5001 and you can grab/create files there.
