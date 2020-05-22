FROM python:3-slim

RUN apt-get update && apt-get install -y --no-install-recommends gnuplot jq bc
RUN pip install slack-cli awscli

WORKDIR /app
COPY cost_monitor_bot.sh .
CMD bash cost_monitor_bot.sh
