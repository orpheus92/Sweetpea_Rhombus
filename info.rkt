#lang info
(define collection "sweetpea-rhm")
(define deps '("base" "rhombus-lib"))
(define pkg-desc "A Rhombus front end for SweetPea experiment designs")
(define version "0.1")
;; tests/ holds designs that MUST fail to compile; keep them out of the
;; package build, or `raco pkg install` reports their errors as build failures.
(define compile-omit-paths '("tests"))
(define test-omit-paths '("tests"))
