#!/usr/bin/env bash

# Variables
dmenu_command="wofi --show dmenu --conf ~/.config/wofi/minimal --style ~/.config/wofi/minimal.css"
browser="zen-browser"

# Prompt the user for input using dmenu
search_query=$(echo "" | eval "$dmenu_command")

# Check if input is not empty
if [ -n "$search_query" ]; then
	# Encode the query for use in a URL
	encoded_query=$(echo "$search_query" | sed 's/ /%20/g')
	# Open the search query in Firefox
	$browser "https://www.google.com/search?q=$encoded_query"
else
	# No input provided. Exiting.
	exit 1
fi
