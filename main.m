// -------------------------------------------------------
// main.m
//
// Copyright (c) 2010 Jakub Suder <jakub.suder@gmail.com>
// Licensed under GPL v3 license
// -------------------------------------------------------

#import <MacRuby/MacRuby.h>

int main(int argc, char *argv[]) {
  return macruby_main("rb_main.rb", argc, argv);
}
