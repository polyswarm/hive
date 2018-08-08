#!/usr/bin/env python

import asyncio
import websockets
import os
import json
import sys
from web3 import Web3 as web3
import datetime
import time

async def run_test():
	test_arbiter = web3.toChecksumAddress(os.environ['TEST_ARBITER'])
	async with websockets.connect('ws://' + os.environ['POLYSWARMD_HOST'] + ':' + os.environ['POLYSWARMD_PORT'] + '/events') as websocket:
		successful_settle = False
		successful_verdict = False
		t_end = time.time() + int(os.environ['TIMEOUT'])

		while (not successful_verdict or not successful_settle) and time.time() < t_end:
			msg = json.loads(await websocket.recv())

			if msg['event'] == 'verdict':
				if msg['data']['voter'] == test_arbiter:
					successful_verdict = True
					print('successful_verdict')
			elif msg['event'] == 'settled_bounty':
				if msg['data']['settler'] == test_arbiter:
					successful_settle = True
					print('successful_settle')

			# exit 0 on successful arbitration
			if successful_settle and successful_verdict:
				sys.exit(0)

		sys.exit(1)

if __name__ == '__main__':
	loop = asyncio.get_event_loop()
	loop.run_until_complete(run_test())
	loop.close()
