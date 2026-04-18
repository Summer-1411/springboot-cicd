package org.example.cicd.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {
    @GetMapping({"/", "/hello"})
    public String hello() {
        return "hello word update version 1.0.1";
    }
}
