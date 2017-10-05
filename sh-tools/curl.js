#!/usr/bin/env node

const {spawn} = require('child_process');

const COOKIE = ''; // set cookie here
const params = [
  '-H', 'pragma: no-cache',
  '-H', 'origin: https://htmlacademy.ru',
  '-H', 'accept-encoding: gzip, deflate, br',
  '-H', 'accept-language: en-US,en;q=0.8,ru;q=0.6',
  '-H', 'user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36',
  '-H', 'content-type: application/x-www-form-urlencoded',
  '-H', 'accept: */*',
  '-H', 'cache-control: no-cache',
  '-H', 'authority: htmlacademy.ru',
  '-H', `cookie: ${COOKIE}`,
  '-H', 'referer: https://htmlacademy.ru/courses/207/run/4',
  '--data', 'task_id=3419&completed=1',
  '--compressed'];

const makeItDone = (course, task) => {
  const url = `https://htmlacademy.ru/courses/${course}/run/${task}`;
  const curl = spawn('curl', [url, ...params]);

  curl.stdout.on('data', (data) => {
    console.log(`stdout: ${data}`);
});

  curl.stderr.on('data', (data) => {
    console.log(`stderr: ${data}`);
});

  curl.on('close', (code) => {
    console.log(`child process exited with code ${code}`);
});
};

const course = 104;
for (let task = 0; task <= 50; task++) {
  makeItDone(course, task);
}
