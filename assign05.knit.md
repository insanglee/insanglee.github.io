---
title: "Assignment 5"
author: "Insang Lee"
format: html
execute:
  warning: false
  message: false
---

## 1. Manual Search and Export

I searched the GovInfo Congressional Hearings collection using the Committee field for "Foreign Relations" and sorted the results from newest to oldest. I exported the search results as a CSV file and retained the ten most recent records for comparison with the API results.

Search query:

`collection:(CHRG) AND publishdate:range(,2026-10-07) AND committee:(Foreign Relations)`


::: {.cell}

```{.r .cell-code}
library(tidyverse)

manual_search <- read_csv("govinfo_manual_search.csv")

manual_top10 <- manual_search |>
  select(
    packageId,
    title,
    publishdate,
    detailsLink,
    pdfLink
  ) |>
  slice_head(n = 10)

manual_top10
```

::: {.cell-output .cell-output-stdout}

```
# A tibble: 10 × 5
   packageId         title                       publishdate detailsLink pdfLink
   <chr>             <chr>                       <date>      <chr>       <chr>  
 1 CHRG-119shrg63909 Arms Control and Transform… 2026-03-24  https://ww… https:…
 2 CHRG-119shrg63707 A Pathway to European Ener… 2026-02-04  https://ww… https:…
 3 CHRG-119shrg64059 Countering Terrorism in No… 2026-02-03  https://ww… https:…
 4 CHRG-119shrg63168 Maritime Security in Afric… 2025-12-10  https://ww… https:…
 5 CHRG-119shrg62398 Combating the People's Rep… 2025-10-07  https://ww… https:…
 6 CHRG-119shrg62961 The Future of U.S. Black S… 2025-09-30  https://ww… https:…
 7 CHRG-119shrg61656 The Status of Democracy an… 2025-07-22  https://ww… https:…
 8 CHRG-119shrg61565 NATO Summit 2025: An Asses… 2025-06-18  https://ww… https:…
 9 CHRG-119shrg60820 East Africa & the Horn: At… 2025-05-13  https://ww… https:…
10 CHRG-119shrg60819 Shared Threats: Indo Pacif… 2025-03-26  https://ww… https:…
```


:::
:::


## 2. GovInfo API

I used the GovInfo Search API to retrieve Congressional Hearings related to the Committee on Foreign Relations. The API request sorted the results by publication date in descending order.











