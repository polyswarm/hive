#!/usr/bin/env python

import asyncio
import websockets
import os
import json
import sys
from web3 import Web3 as web3
loop = asyncio.get_event_loop()
successful_settle = False
successful_verdict = False

async def run_test():
	while True:
		# return sys.exit(1)
		print('get money')

asyncio.get_event_loop().run_until_complete(run_test())
loop.close()
