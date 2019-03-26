#!/usr/bin/env ruby
require "nokogiri"
require "yaml"
require "erb"

PROJECT_BASE = File.expand_path("..", __FILE__)

TAG_TEMPLATE = ERB.new <<-EOF
---
layout: default
title: <%= tag %>
tag: <%= tag %>
---

<div>
<h1>标签·{{ page.tag }}</h1>
  <ul>
  {% for post in site.tags[page.tag] %}
    <li><a href="{{ post.url }}">{{ post.title }}</a> ({{ post.date | date_to_string }})<br>
      {{ post.description }}
    </li>
  {% endfor %}
  </ul>
</div>
EOF

ALBUM_TEMPLATE = ERB.new <<-EOF
---
layout: default
title: <%= album %>
album: <%= album %>
---

<div>
<h1>专辑·{{ page.album }}</h1>
  {% assign album = site.posts | where: "album", "<%= album %>" %}
  <ul>
  {% for post in album %}
    <li><a href="{{ post.url }}">{{ post.title }}</a> ({{ post.date | date_to_string }})<br>
      {{ post.description }}
    </li>
  {% endfor %}
  </ul>
</div>
EOF

system <<~EOF
  cd #{PROJECT_BASE}
  mkdir -p #{PROJECT_BASE}/albums
  rm -fr albums/* tags/*
  bundle exec jekyll build
EOF

tags_page = Nokogiri::HTML(open("#{PROJECT_BASE}/_site/tags.html"))
tags_page.css(".wrapper a code nobr").each do |el|
  tag = el.content
  File.write("#{PROJECT_BASE}/tags/#{tag}.html", TAG_TEMPLATE.result(binding))
end

albums_page = Nokogiri::HTML(open("#{PROJECT_BASE}/_site/albums.html"))
albums_page.css(".wrapper li a").each do |el|
  album = el.content
  File.write("#{PROJECT_BASE}/albums/#{album}.html", ALBUM_TEMPLATE.result(binding))
end
