package org.example.cicd.controller;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController

public class HelloController {
    private static final Logger log = LoggerFactory.getLogger(HelloController.class);


    @GetMapping({"/", "/hello"})
    public String hello() {

        String instanceId = System.getenv("INSTANCE_ID");

        log.info("Request hit instance: {}", instanceId);

        return "hello word update version 1.0.1 - instance: " + instanceId;
    }
}
