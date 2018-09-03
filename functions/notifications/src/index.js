const axios = require('axios');
const slackWebhookUrl = process.env.SLACK_WEBHOOK_URL;

const RED = '#F00';
const GREEN = '#0F0';
const BLUE = '#00F';

const sendSlackNotification = (title, content, color) => {
  axios.post(slackWebhookUrl, {
    attachments: [
      {
        title: title,
        text: content,
        color,
        mrkdwn: true,
      },
    ],
  });
};

module.exports.handler = (event, context, callback) => {
  const sns = event.Records[0].Sns;
  const message = JSON.parse(sns.Message);

  // console.log(message);

  let color = BLUE;

  const pipeline = message.detail.pipeline;
  const state = message.detail.state;

  const title = 'Deployment state update';
  const content = `*${pipeline}* deployment state has changed to *${state}*.`;
  if (state === 'SUCCEEDED') color = GREEN;
  if (state === 'FAILED') color = RED;

  sendSlackNotification(title, content, color);
  callback(null, true);
}
