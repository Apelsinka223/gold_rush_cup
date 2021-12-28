# GoldRushCup

An application for the online championship [Gold Rush Cup](https://cups.mail.ru/en/contests/goldrush) championship.

Finished with [120th](https://cups.mail.ru/en/results/goldrush?page=14&period=past&roundId=598) position in Battle Round.

###[Rules](https://cups.online/en/tasks/1057)

The app was written in order of entertainment, to push Elixir to its boundaries, and to compare different approaches of concurrency.
This is a few-nights project, so it doesn't have tests and CD.

During the development, I have tried to use different tools to build a concurrent working application, like:
- poolboy and pool of domain oriented processes
- GenStage and chain of processes in order to pass the coordinates through
- spawning new process for every API call 😁 

Turns out that spawning new process for every task is the most effective way when you have enough CPU 😅

Some of good decisions:
- algorithm of the area decreasing search
- exploring prioritization, small areas over the large
- digging prioritization, deepest one over rest ones
- algorithm of finding the license the cheapest price
- license holder in one process, that request new license immediately after one is expired and that holds other processes requests without blocking the whole process 
- custom Tesla Plug in order to prioritize one API calls over another, and in order to limit the rate of the calls, since the contest API had a rate limiter

## How to run

- You might want to download and run the [API mock](https://github.com/Apelsinka223/gold_rush_cup_mock) first
- `mix deps.get`
- `iex -S mix run`

## What could have been done better:
- Algorithm to find best price of the license, or even should it be used at all
- Best ratio of the exploring and digging processes amount
