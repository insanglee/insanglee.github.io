# Record Linkage Workshop for EPPS 6302
# Complete R Implementation with Sample Datasets
# Author: Karl Ho
# Updated: 2025

# ============================================================================
# SETUP AND PACKAGE INSTALLATION
# ============================================================================

# Packages required for the workshop (all on CRAN)
required_packages <- c(
  "tidyverse",        # Data manipulation
  "stringdist",       # String similarity metrics
  "phonics",          # Phonetic matching (Soundex, Metaphone, NYSIIS)
  "data.table",       # Fast data operations
  "logger"            # Logging and debugging
)

# Install any missing required packages
missing_pkgs <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]
if (length(missing_pkgs) > 0) install.packages(missing_pkgs)

# Load packages
invisible(lapply(required_packages, library, character.only = TRUE))

# Optional: RecordLinkage is archived on CRAN and fuzzywuzzy is not a CRAN
# package, so they are not required. Students do not need them for this workshop.

# ============================================================================
# PART 1: GENERATE SAMPLE DATASETS
# ============================================================================

set.seed(42)

# Create Texas Government Employee Data (TRS - Teacher Retirement System)
create_trs_data <- function(n = 500) {
  
  first_names <- c("John", "Maria", "Robert", "Jennifer", "Michael", "Sarah",
                   "David", "Patricia", "James", "Linda", "Daniel", "Barbara")
  last_names <- c("Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia",
                  "Miller", "Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez")
  
  trs <- tibble(
    record_id = paste0("TRS_", 1:n),
    first_name = sample(first_names, n, replace = TRUE),
    last_name = sample(last_names, n, replace = TRUE),
    dob = sample(seq(as.Date("1950-01-01"), as.Date("1985-12-31"), by = "day"), n),
    years_service = sample(5:40, n, replace = TRUE),
    salary_group = sample(c("Elementary", "Secondary", "Administration"), n, replace = TRUE),
    retirement_date = NA_Date_
  ) %>%
    mutate(
      # Some retirements for older employees
      retirement_date = case_when(
        years_service > 30 ~ as.Date(paste0(2020 + sample(0:4, n, replace = TRUE), 
                                              "-", 
                                              sample(1:12, n, replace = TRUE, prob = rep(1/12, 12)),
                                              "-01")),
        TRUE ~ NA_Date_
      )
    )
  
  return(trs)
}

# Create Education Agency Data (TEA - Texas Education Agency)
create_tea_data <- function(trs, n = 500, num_matches = 100, corruption_rate = 0.2) {
  
  first_names <- c("John", "Maria", "Robert", "Jennifer", "Michael", "Sarah",
                   "David", "Patricia", "James", "Linda", "Daniel", "Barbara",
                   "Jon", "Mary", "Rob", "Jen", "Mike", "Sara")  # Include variations
  last_names <- c("Smith", "Smithe", "Smyth", "Johnson", "Jonson", "Williams", 
                  "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", 
                  "Martinez", "Hernandez", "Lopez", "Sanchez")
  
  tea <- tibble(
    record_id = paste0("TEA_", 1:n),
    first_name = sample(first_names, n, replace = TRUE),
    last_name = sample(last_names, n, replace = TRUE),
    dob = sample(seq(as.Date("1950-01-01"), as.Date("1985-12-31"), by = "day"), n),
    certification = sample(c("Science", "Math", "English", "Social Studies", "Special Ed"), n, replace = TRUE),
    school_district = sample(paste0("District_", 1:50), n, replace = TRUE),
    hire_date = sample(seq(as.Date("1990-01-01"), as.Date("2020-12-31"), by = "day"), n)
  )
  
  # Make the first num_matches TEA records true matches of TRS_1..TRS_num_matches.
  # The remaining TEA records are unrelated people (true non-matches).
  tea$first_name[1:num_matches] <- trs$first_name[1:num_matches]
  tea$last_name[1:num_matches] <- trs$last_name[1:num_matches]
  tea$dob[1:num_matches] <- trs$dob[1:num_matches]

  # Introduce data quality issues in the matched records only
  # About 20% of matched records have corruption or variation
  corruption_indices <- sample(1:num_matches, size = round(num_matches * corruption_rate), replace = FALSE)
  
  for (idx in corruption_indices) {
    flip <- sample(1:3, 1)
    
    if (flip == 1) {
      # Introduce name variation
      tea$first_name[idx] <- abbreviate(tea$first_name[idx], minlength = 3)
    } else if (flip == 2) {
      # Introduce small typo in last name
      last_chars <- nchar(tea$last_name[idx])
      if (last_chars > 1) {
        typo_pos <- sample(1:last_chars, 1)
        wrong_char <- sample(letters[!(letters %in% unlist(strsplit(tea$last_name[idx], "")))], 1)
        tea$last_name[idx] <- paste0(
          substr(tea$last_name[idx], 1, typo_pos - 1),
          wrong_char,
          substr(tea$last_name[idx], typo_pos + 1, last_chars)
        )
      }
    } else {
      # Shift DOB slightly (data entry error)
      tea$dob[idx] <- tea$dob[idx] + sample(c(-1, 1), 1)
    }
  }
  
  return(tea)
}

# Create a subset of KNOWN matches for validation
create_validation_set <- function(trs, tea, num_matches = 100) {
  
  # Take first 100 records from TRS
  trs_subset <- trs %>% slice(1:num_matches)
  
  # These are the "true" matches in TEA
  true_matches <- tea %>%
    slice(1:num_matches) %>%
    rename_with(~paste0("tea_", .), everything()) %>%
    rename(tea_record_id = tea_record_id)
  
  # Create ground truth
  validation <- tibble(
    trs_record_id = trs_subset$record_id,
    tea_record_id = true_matches$tea_record_id,
    is_match = TRUE
  )
  
  return(validation)
}

# Generate data
cat("Generating sample datasets...\n")
trs_data <- create_trs_data(500)
tea_data <- create_tea_data(trs_data, 500)
validation_set <- create_validation_set(trs_data, tea_data)

# Display sample
cat("\nSample TRS data:\n")
print(head(trs_data, 3))

cat("\nSample TEA data:\n")
print(head(tea_data, 3))

cat("\nGround truth validation set:\n")
print(head(validation_set, 5))

# ============================================================================
# PART 2: DATA STANDARDIZATION AND CLEANING
# ============================================================================

standardize_names <- function(name) {
  name %>%
    tolower() %>%              # Convert to lowercase
    str_trim() %>%             # Remove leading/trailing whitespace
    str_squish() %>%           # Remove extra internal whitespace
    str_replace_all("[^a-z ]", "")  # Remove punctuation/special characters
}

standardize_date <- function(date_col) {
  as.Date(date_col)
}

standardize_zipcodes <- function(zip) {
  # Ensure 5-digit format
  zip <- as.character(zip)
  str_pad(zip, width = 5, side = "left", pad = "0")
}

# Create clean versions
trs_clean <- trs_data %>%
  mutate(
    first_name_std = standardize_names(first_name),
    last_name_std = standardize_names(last_name),
    first_initial = substr(first_name_std, 1, 1),
    dob_std = standardize_date(dob)
  )

tea_clean <- tea_data %>%
  mutate(
    first_name_std = standardize_names(first_name),
    last_name_std = standardize_names(last_name),
    first_initial = substr(first_name_std, 1, 1),
    dob_std = standardize_date(dob)
  )

cat("\nStandardized TRS sample:\n")
print(trs_clean %>% select(record_id, last_name, last_name_std, dob, dob_std) %>% head(3))

# ============================================================================
# PART 3: DETERMINISTIC LINKAGE RULES
# ============================================================================

deterministic_linkage <- function(data_a, data_b, 
                                  id_col_a = "record_id", 
                                  id_col_b = "record_id") {
  
  log_info("Starting deterministic linkage...")
  
  matches <- tibble()
  remaining_a <- data_a
  remaining_b <- data_b
  
  # RULE 1: Exact match on last name + first name + DOB
  # (Highest confidence)
  log_info("Applying Rule 1: Last name + First name + DOB")
  
  rule1 <- remaining_a %>%
    inner_join(
      remaining_b,
      by = c("last_name_std" = "last_name_std",
             "first_name_std" = "first_name_std",
             "dob_std" = "dob_std"),
      suffix = c("_a", "_b")
    ) %>%
    mutate(
      rule_applied = "Rule_1_FullName_DOB",
      confidence = 0.99
    ) %>%
    select(!!sym(paste0(id_col_a, "_a")), 
           !!sym(paste0(id_col_b, "_b")), 
           rule_applied, confidence)
  
  matches <- bind_rows(matches, rule1)
  
  # Remove matched records
  # Matched IDs come back as record_id_a / record_id_b (from the suffixes)
  remaining_a <- anti_join(remaining_a, rule1, by = setNames("record_id_a", id_col_a))
  remaining_b <- anti_join(remaining_b, rule1, by = setNames("record_id_b", id_col_b))
  
  log_info(paste("Rule 1 found", nrow(rule1), "matches"))
  
  # RULE 2: Last name + Last name initial + DOB
  # (For records where first name varies slightly)
  log_info("Applying Rule 2: Last name + First initial + DOB")
  
  rule2 <- remaining_a %>%
    inner_join(
      remaining_b,
      by = c("last_name_std" = "last_name_std",
             "first_initial" = "first_initial",
             "dob_std" = "dob_std"),
      suffix = c("_a", "_b")
    ) %>%
    mutate(
      rule_applied = "Rule_2_LastName_Initial_DOB",
      confidence = 0.95
    ) %>%
    select(record_id_a, record_id_b, rule_applied, confidence)

  matches <- bind_rows(matches, rule2)
  remaining_a <- anti_join(remaining_a, rule2, by = setNames("record_id_a", id_col_a))
  remaining_b <- anti_join(remaining_b, rule2, by = setNames("record_id_b", id_col_b))
  
  log_info(paste("Rule 2 found", nrow(rule2), "matches"))
  
  # RULE 3: Last name + First name + DOB within 1 day
  # (For data entry errors on DOB)
  log_info("Applying Rule 3: Last name + First name + DOB (±1 day)")
  
  rule3 <- remaining_a %>%
    cross_join(remaining_b, suffix = c("_a", "_b")) %>%
    filter(
      last_name_std_a == last_name_std_b,
      first_name_std_a == first_name_std_b,
      abs(as.numeric(difftime(dob_std_a, dob_std_b, units = "days"))) <= 1
    ) %>%
    select(record_id_a, record_id_b) %>%
    mutate(
      rule_applied = "Rule_3_DOBFlex",
      confidence = 0.90
    )

  if (nrow(rule3) > 0) {
    # Remove duplicates (keep first match only)
    rule3 <- rule3 %>% distinct(record_id_a, .keep_all = TRUE)
    matches <- bind_rows(matches, rule3)
    remaining_a <- anti_join(remaining_a, rule3, by = setNames("record_id_a", id_col_a))
    remaining_b <- anti_join(remaining_b, rule3, by = setNames("record_id_b", id_col_b))
  }
  
  log_info(paste("Rule 3 found", nrow(rule3), "matches"))
  
  result <- list(
    matches = matches,
    remaining_a = remaining_a,
    remaining_b = remaining_b,
    summary = tibble(
      Rule = c("Rule 1", "Rule 2", "Rule 3"),
      Matches = c(nrow(rule1), nrow(rule2), nrow(rule3))
    )
  )
  
  return(result)
}

# Execute deterministic linkage
det_result <- deterministic_linkage(trs_clean, tea_clean)

cat("\nDeterministic Linkage Summary:\n")
print(det_result$summary)

cat("\nFirst 5 deterministic matches:\n")
print(head(det_result$matches, 5))

# ============================================================================
# PART 4: PROBABILISTIC LINKAGE - SIMILARITY SCORING
# ============================================================================

# Calculate string similarity using Jaro-Winkler
calculate_string_similarity <- function(str1, str2, method = "jw") {
  
  if (is.na(str1) | is.na(str2)) {
    return(NA_real_)
  }
  
  # Jaro-Winkler returns distance (0-1), we want similarity
  1 - stringdist(str1, str2, method = method)
}

# Vectorized version for efficiency
calculate_similarity_matrix <- function(data_a, data_b, 
                                        field_a, field_b,
                                        method = "jw") {
  
  similarity_matrix <- matrix(
    nrow = nrow(data_a),
    ncol = nrow(data_b)
  )
  
  for (i in 1:nrow(data_a)) {
    for (j in 1:nrow(data_b)) {
      similarity_matrix[i, j] <- calculate_string_similarity(
        data_a[[field_a]][i],
        data_b[[field_b]][j],
        method = method
      )
    }
  }
  
  return(similarity_matrix)
}

# More efficient: Use vectorized stringdistmatrix
calculate_similarity_efficient <- function(data_a_field, data_b_field) {
  
  dist_matrix <- stringdistmatrix(
    data_a_field,
    data_b_field,
    method = "jw",
    useNames = "strings"
  )
  
  # Convert distance to similarity (1 - distance)
  similarity <- 1 - dist_matrix
  
  return(similarity)
}

# For unmatched records, compute similarities
unmatched_a <- det_result$remaining_a
unmatched_b <- det_result$remaining_b

cat(paste("\nComputing probabilistic matches for", 
          nrow(unmatched_a), "unmatched records in TRS and",
          nrow(unmatched_b), "in TEA...\n"))

# Calculate similarities for each field
last_name_sim <- calculate_similarity_efficient(
  unmatched_a$last_name_std,
  unmatched_b$last_name_std
)

first_name_sim <- calculate_similarity_efficient(
  unmatched_a$first_name_std,
  unmatched_b$first_name_std
)

# DOB exact match (1 if exact, 0 if different, 0.95 if within 1 day)
# Rows = records in unmatched_a, columns = records in unmatched_b
# (same orientation as the name-similarity matrices)
dob_sim <- outer(
  as.numeric(unmatched_a$dob_std),
  as.numeric(unmatched_b$dob_std),
  function(x, y) {
    diff_days <- abs(x - y)
    ifelse(diff_days == 0, 1.0, ifelse(diff_days == 1, 0.95, 0.0))
  }
)

# Convert to dataframes for easier manipulation
all_comparisons <- expand_grid(
  idx_a = 1:nrow(unmatched_a),
  idx_b = 1:nrow(unmatched_b)
) %>%
  mutate(
    record_id_a = unmatched_a$record_id[idx_a],
    record_id_b = unmatched_b$record_id[idx_b],
    
    # Extract similarities
    last_name_sim = sapply(1:n(), function(k) {
      last_name_sim[idx_a[k], idx_b[k]]
    }),
    first_name_sim = sapply(1:n(), function(k) {
      first_name_sim[idx_a[k], idx_b[k]]
    }),
    dob_sim = sapply(1:n(), function(k) {
      dob_sim[idx_a[k], idx_b[k]]
    })
  ) %>%
  select(record_id_a, record_id_b, last_name_sim, first_name_sim, dob_sim)

# Calculate weighted match score
# Weights can be adjusted based on domain knowledge
all_comparisons <- all_comparisons %>%
  mutate(
    match_score = (
      last_name_sim * 0.40 +   # Last name most important
      first_name_sim * 0.30 +  # First name medium importance
      dob_sim * 0.30           # DOB medium importance
    )
  )

cat("\nMatch score distribution:\n")
print(all_comparisons %>%
  summarise(
    min = min(match_score),
    q25 = quantile(match_score, 0.25),
    median = median(match_score),
    q75 = quantile(match_score, 0.75),
    max = max(match_score),
    n = n()
  ))

# Apply thresholds
probabilistic_matches <- all_comparisons %>%
  mutate(
    classification = case_when(
      match_score > 0.95 ~ "LINK",
      match_score >= 0.85 & match_score <= 0.95 ~ "REVIEW",
      TRUE ~ "NO_LINK"
    )
  ) %>%
  filter(classification %in% c("LINK", "REVIEW"))

cat("\nProbabilistic matches by classification:\n")
print(probabilistic_matches %>%
  count(classification))

cat("\nSample LINK decisions (high confidence):\n")
print(probabilistic_matches %>%
  filter(classification == "LINK") %>%
  head(5))

cat("\nSample REVIEW decisions (uncertain):\n")
print(probabilistic_matches %>%
  filter(classification == "REVIEW") %>%
  head(5))

# ============================================================================
# PART 5: VALIDATION AND QUALITY ASSESSMENT
# ============================================================================

# Combine deterministic and probabilistic matches
all_matches <- bind_rows(
  det_result$matches %>%
    select(record_id_a, record_id_b) %>%
    mutate(match_score = 0.99, source = "Deterministic"),
  
  probabilistic_matches %>%
    filter(classification == "LINK") %>%
    select(record_id_a, record_id_b, match_score) %>%
    mutate(source = "Probabilistic_Auto")
)

# Add TEA record IDs for cross-reference
all_matches <- all_matches %>%
  mutate(
    trs_record_id = record_id_a,
    tea_record_id = record_id_b
  ) %>%
  select(trs_record_id, tea_record_id, match_score, source)

# ============================================================================
# ASSESSMENT: PRECISION, RECALL, F1-SCORE
# ============================================================================

assess_linkage_quality <- function(all_matches, validation_set) {
  
  log_info("Assessing linkage quality against validation set...")
  
  # Convert to comparable format
  our_matches <- all_matches %>%
    mutate(our_match = 1) %>%
    select(trs_record_id, tea_record_id, our_match)
  
  true_matches <- validation_set %>%
    rename(trs_record_id = trs_record_id, 
           tea_record_id = tea_record_id) %>%
    mutate(true_match = 1) %>%
    select(trs_record_id, tea_record_id, true_match)
  
  # Full outer join to get all possibilities
  assessment <- true_matches %>%
    full_join(our_matches, 
              by = c("trs_record_id", "tea_record_id")) %>%
    mutate(
      true_match = replace_na(true_match, 0),
      our_match = replace_na(our_match, 0)
    )
  
  # Calculate metrics
  tp <- sum(assessment$true_match == 1 & assessment$our_match == 1)  # True positives
  fp <- sum(assessment$true_match == 0 & assessment$our_match == 1)  # False positives
  fn <- sum(assessment$true_match == 1 & assessment$our_match == 0)  # False negatives
  tn <- sum(assessment$true_match == 0 & assessment$our_match == 0)  # True negatives
  
  precision <- if (tp + fp > 0) tp / (tp + fp) else NA_real_
  recall <- if (tp + fn > 0) tp / (tp + fn) else NA_real_
  f1 <- if (!is.na(precision) & !is.na(recall) & precision + recall > 0) {
    2 * (precision * recall) / (precision + recall)
  } else {
    NA_real_
  }
  
  accuracy <- (tp + tn) / nrow(assessment)
  
  results <- list(
    metrics = tibble(
      Metric = c("Precision", "Recall", "F1-Score", "Accuracy"),
      Value = c(precision, recall, f1, accuracy),
      Interpretation = c(
        "Of matches we made, what % were correct?",
        "Of all true matches, what % did we find?",
        "Harmonic mean of precision and recall",
        "What % of all decisions were correct?"
      )
    ),
    confusion_matrix = tibble(
      Metric = c("True Positives", "False Positives", "False Negatives", "True Negatives"),
      Count = c(tp, fp, fn, tn)
    ),
    detailed = assessment
  )
  
  return(results)
}

# Run assessment
quality_assessment <- assess_linkage_quality(all_matches, validation_set)

cat("\n=== LINKAGE QUALITY ASSESSMENT ===\n")
cat("Performance Metrics:\n")
print(quality_assessment$metrics)

cat("\nConfusion Matrix:\n")
print(quality_assessment$confusion_matrix)

# ============================================================================
# PART 6: DIAGNOSTIC AND TROUBLESHOOTING
# ============================================================================

# False positives: Matches we made that shouldn't have
false_positives <- quality_assessment$detailed %>%
  filter(true_match == 0 & our_match == 1) %>%
  left_join(
    all_matches %>% select(trs_record_id, tea_record_id, match_score),
    by = c("trs_record_id", "tea_record_id")
  ) %>%
  select(trs_record_id, tea_record_id, match_score)

cat("\n=== FALSE POSITIVES (Incorrect Matches) ===\n")
if (nrow(false_positives) > 0) {
  cat("Found", nrow(false_positives), "false positives. Examples:\n")
  print(head(false_positives, 3))
  
  cat("\nMatch scores of false positives:\n")
  print(summary(false_positives$match_score))
} else {
  cat("No false positives! Excellent precision.\n")
}

# False negatives: Matches we missed
false_negatives <- quality_assessment$detailed %>%
  filter(true_match == 1 & our_match == 0) %>%
  select(trs_record_id, tea_record_id)

cat("\n=== FALSE NEGATIVES (Missed Matches) ===\n")
if (nrow(false_negatives) > 0) {
  cat("Found", nrow(false_negatives), "false negatives (missed matches). Examples:\n")
  print(head(false_negatives, 3))
  
  # Investigate why we missed these
  investigation <- false_negatives %>%
    slice(1) %>%  # Investigate first missed match
    left_join(all_comparisons, 
              by = c("trs_record_id" = "record_id_a", 
                     "tea_record_id" = "record_id_b"))
  
  if (nrow(investigation) > 0) {
    cat("\nWhy did we miss this match?\n")
    print(investigation %>% select(last_name_sim, first_name_sim, dob_sim, match_score))
  }
} else {
  cat("No false negatives! Excellent recall.\n")
}

# ============================================================================
# PART 7: SENSITIVITY ANALYSIS
# ============================================================================

sensitivity_analysis <- function(all_comparisons) {
  
  log_info("Running sensitivity analysis on thresholds...")
  
  thresholds <- seq(0.70, 0.99, by = 0.05)
  
  results <- tibble()
  
  for (threshold in thresholds) {
    
    test_matches <- all_comparisons %>%
      filter(match_score >= threshold) %>%
      mutate(our_match = 1) %>%
      select(record_id_a, record_id_b, our_match)
    
    # Quick assessment (using first 100 validation records)
    # This is illustrative - full validation would use complete validation set
    assessment <- validation_set %>%
      slice(1:min(100, nrow(validation_set))) %>%
      rename(record_id_a = trs_record_id, record_id_b = tea_record_id) %>%
      full_join(test_matches, by = c("record_id_a", "record_id_b")) %>%
      mutate(
        is_match = replace_na(is_match, 0),
        our_match = replace_na(our_match, 0)
      )
    
    tp <- sum(assessment$is_match == 1 & assessment$our_match == 1)
    fp <- sum(assessment$is_match == 0 & assessment$our_match == 1)
    fn <- sum(assessment$is_match == 1 & assessment$our_match == 0)
    
    precision <- if (tp + fp > 0) tp / (tp + fp) else 0
    recall <- if (tp + fn > 0) tp / (tp + fn) else 0
    f1 <- if (precision + recall > 0) 2 * (precision * recall) / (precision + recall) else 0
    
    results <- bind_rows(results, tibble(
      threshold = threshold,
      num_matches = nrow(test_matches),
      precision = precision,
      recall = recall,
      f1 = f1
    ))
  }
  
  return(results)
}

sensitivity_results <- sensitivity_analysis(all_comparisons)

cat("\n=== SENSITIVITY ANALYSIS ===\n")
cat("Performance across different thresholds:\n")
print(sensitivity_results)

# Visualize sensitivity
plot_sensitivity <- sensitivity_results %>%
  select(threshold, precision, recall, f1) %>%
  pivot_longer(-threshold, names_to = "metric", values_to = "value") %>%
  ggplot(aes(x = threshold, y = value, color = metric, linetype = metric)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  labs(
    title = "Linkage Quality vs. Threshold",
    x = "Match Score Threshold",
    y = "Performance Metric",
    color = "Metric",
    linetype = "Metric"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5), legend.position = "bottom", text = element_text(family="Palatino"))

cat("\n[Sensitivity plot would display here if interactive]\n")

# ============================================================================
# PART 8: FINAL RECOMMENDATIONS AND DOCUMENTATION
# ============================================================================

create_linkage_report <- function(quality_metrics, match_decisions, all_matches) {
  
  cat("\n")
  cat(strrep("=", 50), "\n", sep = "")
  cat("RECORD LINKAGE PROJECT COMPLETION REPORT\n")
  cat(strrep("=", 50), "\n", sep = "")
  
  cat("\n## SUMMARY OF RESULTS\n\n")
  
  cat("Total records in TRS database:", nrow(trs_data), "\n")
  cat("Total records in TEA database:", nrow(tea_data), "\n")
  cat("Successful matches found:", nrow(all_matches), "\n")
  cat("Match rate:", round(nrow(all_matches) / nrow(trs_data) * 100, 1), "%\n\n")
  
  cat("## QUALITY METRICS\n\n")
  print(quality_metrics$metrics)
  
  cat("\n## RECOMMENDATIONS\n\n")
  
  cat("1. THRESHOLD SELECTION\n")
  cat("   Current: 0.95 for automatic linking, 0.85-0.95 for review\n")
  cat("   Recommendation: Consider adjusting based on your precision/recall tradeoff\n")
  cat("   - If you value precision (few false matches): Keep threshold at 0.95+\n")
  cat("   - If you value recall (find all matches): Lower to 0.85\n\n")
  
  cat("2. UNMATCHED RECORDS REVIEW\n")
  cat("   Manual review recommended for", 
      sum(probabilistic_matches$classification == "REVIEW"), 
      "uncertain cases\n\n")
  
  cat("3. DATA QUALITY IMPROVEMENT\n")
  cat("   - Standardize name formats in source systems\n")
  cat("   - Validate dates of birth at point of entry\n")
  cat("   - Consider implementing unique identifiers\n\n")
  
  cat("4. PRIVACY AND SECURITY\n")
  cat("   - Store linked data with access restrictions\n")
  cat("   - Never release individual-level matches without IRB approval\n")
  cat("   - Consider aggregating results before publication\n\n")
  
  cat("5. DOCUMENTATION\n")
  cat("   - Linkage rules have been logged above\n")
  cat("   - Reproducible workflow maintained\n")
  cat("   - Save this report with final dataset\n")
}

create_linkage_report(quality_assessment, probabilistic_matches, all_matches)

# ============================================================================
# PART 9: EXPORT RESULTS
# ============================================================================

# Save matched dataset
matched_dataset <- trs_clean %>%
  inner_join(
    all_matches %>% select(trs_record_id, tea_record_id, match_score),
    by = c("record_id" = "trs_record_id")
  ) %>%
  inner_join(
    tea_clean %>% rename_with(~paste0("tea_", .), everything()),
    by = c("tea_record_id" = "tea_record_id")
  )

# Save for external use (select relevant columns)
export_dataset <- matched_dataset %>%
  select(
    trs_record_id = record_id,
    tea_record_id = tea_record_id,
    match_score,
    
    # From TRS
    trs_first_name = first_name,
    trs_last_name = last_name,
    trs_dob = dob,
    trs_salary_group = salary_group,
    
    # From TEA
    tea_certification = tea_certification,
    tea_school_district = tea_school_district,
    tea_hire_date = tea_hire_date
  ) %>%
  arrange(desc(match_score))

cat("\n## FINAL DATASET\n")
cat("Successfully linked", nrow(export_dataset), "record pairs\n")
print(head(export_dataset, 10))

# ============================================================================
# PART 10: TROUBLESHOOTING GUIDE
# ============================================================================

troubleshooting_guide <- function() {
  
  guide <- list(
    
    problem_1 = list(
      title = "Too many false matches",
      symptoms = "Precision is low, many matches seem wrong",
      solutions = c(
        "Increase match_score threshold (e.g., 0.95 → 0.97)",
        "Add additional matching fields (e.g., birth state, county)",
        "Use stricter similarity metrics (e.g., Levenshtein instead of Jaro-Winkler)",
        "Manually review uncertain matches in REVIEW category"
      )
    ),
    
    problem_2 = list(
      title = "Too many missed matches",
      symptoms = "Recall is low, many valid matches not found",
      solutions = c(
        "Lower match_score threshold (e.g., 0.90 → 0.85)",
        "Account for common data quality issues (middle initials, suffixes)",
        "Use phonetic matching (Soundex) for names",
        "Consider blocking on partial fields (first few letters)",
        "Investigate false negatives to identify patterns"
      )
    ),
    
    problem_3 = list(
      title = "Script runs slowly",
      symptoms = "Comparison matrix creation takes minutes/hours",
      solutions = c(
        "Implement blocking: only compare similar records",
        "Use parallel processing with stringdistmatrix",
        "Sample data for initial testing",
        "Reduce to essential matching fields"
      )
    ),
    
    problem_4 = list(
      title = "One-to-many or many-to-many matches",
      symptoms = "Some records match multiple others",
      solutions = c(
        "Filter to keep only highest score match per record",
        "Increase match threshold",
        "Review linking rules for correctness",
        "Check for duplicate records in source data"
      )
    ),
    
    problem_5 = list(
      title = "Poor agreement on test cases",
      symptoms = "Known matches have low similarity scores",
      solutions = c(
        "Examine actual names: may require special handling",
        "Check for data entry errors in test set",
        "Investigate date discrepancies (different reference dates?)",
        "Consider name standardization rules (remove suffixes, handle nicknames)",
        "Review field weights in scoring"
      )
    )
  )
  
  return(guide)
}

# Display troubleshooting guide
guide <- troubleshooting_guide()

cat("\n")
cat(strrep("=", 50), "\n", sep = "")
cat("TROUBLESHOOTING GUIDE\n")
cat(strrep("=", 50), "\n", sep = "")

for (i in 1:length(guide)) {
  problem <- guide[[i]]
  cat("\n[", i, "] ", problem$title, "\n", sep = "")
  cat("Symptoms: ", problem$symptoms, "\n", sep = "")
  cat("Solutions:\n")
  for (j in 1:length(problem$solutions)) {
    cat("  ", j, ". ", problem$solutions[j], "\n", sep = "")
  }
}

cat("\n")
cat(strrep("=", 50), "\n", sep = "")
cat("END OF WORKSHOP\n")
cat(strrep("=", 50), "\n", sep = "")

