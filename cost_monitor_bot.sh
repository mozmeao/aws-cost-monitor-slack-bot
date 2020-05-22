#!/usr/bin/env bash
set -euo pipefail

AWS_REPLY=$(mktemp)
PROCESSED_REPLY=$(mktemp)
NUMBERS_ONLY=$(mktemp)
PLOT=$(mktemp --suffix ".png")


add_lines() {
     echo "$@" | tr " " "+" | bc
}

format_currency() {
    printf "%0.2f" $1 | sed -r ':a;s/(^|[^0-9.])([0-9]+)([0-9]{3})/\1\2,\3/g;ta'
}

aws ce get-cost-and-usage \
    --time-period Start=$(date +"%Y-12-01" --date="-1 year"),End=$(date +"%Y-%m-%d") \
    --granularity=DAILY  \
    --metrics BlendedCost > ${AWS_REPLY}


cat ${AWS_REPLY} | jq -r '.ResultsByTime[] | .TimePeriod.Start + " " + .Total.BlendedCost.Amount' > ${PROCESSED_REPLY}
cat ${PROCESSED_REPLY} | cut -d " " -f 2 > ${NUMBERS_ONLY}

COST_YESTERDAY=$(format_currency $(cat ${NUMBERS_ONLY} | tail -n 1))
COST_MTD=$(format_currency $(add_lines $(cat ${NUMBERS_ONLY} | tail -n $(date +%d --date="-1 days"))))
COST_YTD=$(format_currency $(cat ${NUMBERS_ONLY} | tail -n +32 | paste -sd+ | bc))

MSG="AWS Spendings ➤ Yesterday: \$${COST_YESTERDAY} | MTD \$${COST_MTD} | YTD \$${COST_YTD}"
gnuplot -e """
  set xdata time;
  set timefmt '%Y-%m-%d';
  set ylabel 'Cost ($)';
  set xrange [\"$(date +%Y-%m-%d --date='-30 days')\":\"$(date +%Y-%m-%d)\"];
  set yrange [100:300];
  set grid;
  set style line 1 lc rgb '#0060ad' lt 1 lw 2 pt 7 pi -1 ps 1.5;
  set terminal png size 800,300;
  set output '${PLOT}';
  plot '${PROCESSED_REPLY}' using 1:2 with linespoints ls 1 title 'AWS Cost';
"""

echo $MSG
echo $PLOT

if [ -n "${SLACK_TOKEN:-}" ]
then
    echo "Sending to Slack channel ${SLACK_CHANNEL:-giorgos}"
    slack-cli -t ${SLACK_TOKEN} -d ${SLACK_CHANNEL:-giorgos} "${MSG}"
    slack-cli -t ${SLACK_TOKEN} -d ${SLACK_CHANNEL:-giorgos} -f "${PLOT}"
fi
