package org.example.cicd.service;

import org.example.cicd.entity.Todo;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

@Service
public class TodoService {
    private final Map<Long, Todo> store = new ConcurrentHashMap<>();
    private final AtomicLong idGen = new AtomicLong(1);

    public List<Todo> findAll() {
        return new ArrayList<>(store.values());
    }

    public Optional<Todo> findById(Long id) {
        return Optional.ofNullable(store.get(id));
    }

    public Todo create(Todo todo) {
        long id = idGen.getAndIncrement();
        todo.setId(id);
        store.put(id, todo);
        return todo;
    }

    public Optional<Todo> update(Long id, Todo todo) {
        return Optional.ofNullable(store.computeIfPresent(id, (k, existing) -> {
            if (todo.getTitle() != null) existing.setTitle(todo.getTitle());
            existing.setCompleted(todo.isCompleted());
            return existing;
        }));
    }

    public boolean delete(Long id) {
        return store.remove(id) != null;
    }
}
