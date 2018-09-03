pack_notifications:
	cd functions/notifications/src && rm -rf node_modules && npm install --production && npm run pack && npm install
