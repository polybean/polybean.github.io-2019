---
title: "0033 - [M001]Challenge Problem: Single Value in an Array of Integers"
tags: ["MongoDB University"]
album: "M001: MongoDB Basics"
---

## 问题

In the M001 class Atlas cluster you will find a database added just for this week of the course. It is called results. Within this database you will find two collections: `surveys` and `scores`. Documents in the `results.scores` collection have the following schema.

```json
{ "_id": ObjectId("5964e8e5f0df64e7bc2d7373"), "results": [75, 88, 89] }
```

Connect to our class Atlas cluster from the mongo shell or Compass and view the `results.scores` collection. How many documents contain at least one score in the results array that is greater than or equal to 70 and less than 80?

## 解析

查询条件：

```json
{ "results": { "$elemMatch": { "$gte": 70, "$lt": 80 } } }
```

![](/assets/images/2019/0033/answer.png)

## 答案

`744`
