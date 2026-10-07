library(tidyverse)

ggplot(
  hpi,
  aes(
    x = `GDP per capita`,
    y = `Life Expectancy`
  )
) +                                      # data + aesthetics
  
  geom_point(
    aes(
      size = Population,
      colour = factor(Continent)
    ),
    alpha = 0.6
  ) +                                    # geom + aesthetics
  
  geom_smooth(
    method = "loess",
    se = FALSE
  ) +                                    # stat / smoother
  
  scale_x_log10(
    labels = scales::label_dollar()
  ) +                                    # scale
  
  labs(
    title = "Richer countries live longer, up to a point",
    x = "GDP per capita (log scale)",
    y = "Life expectancy (years)",
    colour = "Continent",
    caption = "Source: Happy Planet Index"
  ) +                                    # labels
  
  theme_minimal() +                      # theme
  facet_wrap(~ factor(Continent))      # facet


# Change made:
# Adding facet_wrap() separates the data by continent and makes it easier
# to compare the relationship between GDP per capita and life expectancy
# across groups.