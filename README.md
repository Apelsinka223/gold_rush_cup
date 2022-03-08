# GoldRushCup

An application for the online championship [Gold Rush Cup](https://cups.mail.ru/en/contests/goldrush).
The goal is to find as big amount of treasure chests on the field as you can.   
To find a chest you need to follow steps:  
1. Send an exploring request to API for an area by calculated coordinates. It can differes by size. The more an area is the more time it requires to explore.
2. If the request returned that area contains a treasure, you can send a digging request to API. Since the field has multiple level of depth, a treasure can be placed at any of them. The deeper area is the longer time it will consume to dig.
3. When you find a chest you should send an exchanginf request to exchange it to coins. This coins makes you points, but also could be spent for a licenses that helps you dig faster (and also are required after 50 digging requests).

To master this task you need to make fast and concurrent requests and calculations, and also you need to mind an algorithm for dealing with digging licenses.
You also need to keep in mind that provided API has some limit on amount of concurrent requests and need to avoid errors caused by ddos protection.

With this solution I finished with [120th](https://cups.mail.ru/en/results/goldrush?page=14&period=past&roundId=598) position in Battle Round.

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
