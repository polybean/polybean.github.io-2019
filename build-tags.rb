#!/usr/bin/env ruby
require "nokogiri"
require "erb"

PROJECT_BASE = File.expand_path("..", __FILE__)

template = ERB.new <<-EOF
---
layout: default
title: <%= tag %>
tag: <%= tag %>
---

<div>
<h1>Tag: {{ page.tag }}</h1>
  <ul>
  {% for post in site.tags[page.tag] %}
    <li><a href="{{ post.url }}">{{ post.title }}</a> ({{ post.date | date_to_string }})<br>
      {{ post.description }}
    </li>
  {% endfor %}
  </ul>
</div>
EOF

system "cd #{PROJECT_BASE} && bundle exec jekyll build"

page = Nokogiri::HTML(open("_site/tags.html"))
page.css(".wrapper a code nobr").each do |el|
  tag = el.content
  File.write("#{PROJECT_BASE}/tags/#{tag}.html", template.result(binding))
end
