package com.recipes.service;

import com.recipes.model.Recipe;
import com.recipes.repository.RecipeRepository;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

@Service
public class RecipeService {

    private final RecipeRepository repository;

    public RecipeService(RecipeRepository repository) {
        this.repository = repository;
    }

    public List<Recipe> findAll() {
        return repository.findAll();
    }

    public Optional<Recipe> findById(String id) {
        return repository.findById(id);
    }

    public Recipe create(Recipe recipe) {
        recipe.setCreatedAt(Instant.now());
        recipe.setUpdatedAt(Instant.now());
        return repository.save(recipe);
    }

    public Optional<Recipe> update(String id, Recipe updated) {
        return repository.findById(id).map(existing -> {
            existing.setTitle(updated.getTitle());
            existing.setIngredients(updated.getIngredients());
            existing.setInstructions(updated.getInstructions());
            existing.setUpdatedAt(Instant.now());
            return repository.save(existing);
        });
    }

    public boolean delete(String id) {
        if (repository.existsById(id)) {
            repository.deleteById(id);
            return true;
        }
        return false;
    }
}
