# GoldRushCup

An application for the online championship [Gold Rush Cup](https://cups.mail.ru/en/contests/goldrush) championship.

Finished with [120th](https://cups.mail.ru/en/results/goldrush?page=14&period=past&roundId=598) position in Battle Round.

The app was written in order of enterntainship, to push Elixir to its boundaries, and to compair different approaches of concurrency.
Don't take it too seriously 🙂

During the development, I tried to use different tools to build a concurrent working application, like:
- poolboy and pool of domain oriented processes
- GenStage and chain of processes in order to pass the coordinates through
- spawning new process for every API call 😁 

Turns out that spawning new process for every task is the most effective way, when you have enought CPU 😅
But you can find part of every of this approaches remained in the final version of the application, as far as I haven't got enought time (and willing) to refactor it.

Some of the good decisions:
- algorithm of the area decreasing search
- exploring prioritization, small areas over the large
- digging prioritization, deepest one over the rest ones
- alghorithm of the finding the license cheapest price
- license holder in one process, that request new license immidiatly after one is expired and that holds other processes requests without blocking the whole process 
- custom Tesla Plug in order to prioritize one API calls over another, and in order to limit the rate of the calls, since the contest API had a rate limiter

## How to run

- You might want to download and run the [API mock](https://github.com/Apelsinka223/gold_rush_cup_mock) first.
- `mix deps.get`
- `mix run`

## What could have been done better:
- Algorithm to find best price of the license, or even should it be used at all
- Best ratio of the exploring and digging processes amount
