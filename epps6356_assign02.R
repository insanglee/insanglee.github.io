# EPPS 6356 - Assignment 2

library(readxl)

hpi <- read_excel(
  "Happy-Planet-Index-2006-2025-public-data-set.xlsx",
  sheet="All Data",
  skip=1
)

View(hpi)

# Use 2025 because it is the most recent year available in the dataset.

hpi_2025 <- subset(hpi, Year == 2025)

View(hpi_2025)
nrow(hpi_2025)

# Reset graphics settings from previous exercises
par(mfrow=c(1, 1), pty="m")


# 1. par()

par(mar=c(5, 5, 3, 2))

plot(
  hpi_2025$`Life Expectancy`,
  hpi_2025$`Life Satisfaction`,
  xlab="Life Expectancy",
  ylab="Life Satisfaction",
  main="Life Expectancy and Life Satisfaction, 2025",
  pch=16
)


# 2. box()

plot(
  hpi_2025$`Life Expectancy`,
  hpi_2025$`Life Satisfaction`,
  xlab="Life Expectancy",
  ylab="Life Satisfaction",
  main="Life Expectancy and Life Satisfaction, 2025",
  pch=16,
  axes=FALSE
)

axis(1)
axis(2)
box()


# 3. axis()

plot(
  hpi_2025$`Life Expectancy`,
  hpi_2025$`Life Satisfaction`,
  xlab="",
  ylab="",
  main="Life Expectancy and Life Satisfaction, 2025",
  pch=16,
  axes=FALSE
)

axis(
  side=1,
  at=seq(55, 85, by=5)
)

axis(
  side=2,
  at=seq(3, 8, by=1)
)

box()

mtext("Life Expectancy", side=1, line=3)
mtext("Life Satisfaction", side=2, line=3)


# 4. hist()

hist(
  hpi_2025$`Life Expectancy`,
  main="Distribution of Life Expectancy, 2025",
  xlab="Life Expectancy",
  ylab="Frequency"
)


# 5. boxplot()

boxplot(
  hpi_2025$`Life Satisfaction`,
  main="Distribution of Life Satisfaction, 2025",
  ylab="Life Satisfaction"
)


# 6. pie()

continent_names <- c(
  "Latin America",
  "N America & Oceania",
  "Western Europe",
  "Middle East & N. Africa",
  "Africa",
  "South Asia",
  "Eastern Europe & Central Asia",
  "East Asia"
)

continent_counts <- table(hpi_2025$Continent)

pie(
  continent_counts,
  labels=continent_names,
  main="Countries by Continent, 2025"
)


# 7. persp()

le_group <- cut(
  hpi_2025$`Life Expectancy`,
  breaks=5,
  labels=FALSE
)

ls_group <- cut(
  hpi_2025$`Life Satisfaction`,
  breaks=5,
  labels=FALSE
)

z_matrix <- tapply(
  hpi_2025$`Ecological Footprint`,
  list(le_group, ls_group),
  mean,
  na.rm=TRUE
)

z_matrix[is.na(z_matrix)] <- mean(
  hpi_2025$`Ecological Footprint`,
  na.rm=TRUE
)

par(mar=c(2, 2, 3, 2))

persp(
  x=1:5,
  y=1:5,
  z=z_matrix,
  theta=30,
  phi=30,
  expand=0.8,
  ticktype="detailed",
  xlab="Life Expectancy Group",
  ylab="Life Satisfaction Group",
  zlab="Mean Ecological Footprint",
  main="Mean Ecological Footprint, 2025"
)


# Reset margins after persp()
par(mar=c(5, 4, 4, 2) + 0.1)


# 8. points()

plot(
  hpi_2025$`Life Expectancy`,
  hpi_2025$`Life Satisfaction`,
  xlab="Life Expectancy",
  ylab="Life Satisfaction",
  main="Life Expectancy and Life Satisfaction, 2025",
  pch=1
)

high_life <- hpi_2025$`Life Expectancy` >= 80

points(
  hpi_2025$`Life Expectancy`[high_life],
  hpi_2025$`Life Satisfaction`[high_life],
  pch=16
)


# 9. lines()

x <- hpi_2025$`Life Expectancy`
y <- hpi_2025$`Life Satisfaction`

plot(
  x,
  y,
  xlab="Life Expectancy",
  ylab="Life Satisfaction",
  main="Life Expectancy and Life Satisfaction, 2025",
  pch=16
)

fit <- lm(y ~ x)

x_line <- seq(
  min(x, na.rm=TRUE),
  max(x, na.rm=TRUE),
  length.out=100
)

y_line <- predict(
  fit,
  newdata=data.frame(x=x_line)
)

lines(
  x_line,
  y_line,
  lwd=2
)


# 10. text()

plot(
  hpi_2025$`Life Expectancy`,
  hpi_2025$`Life Satisfaction`,
  xlab="Life Expectancy",
  ylab="Life Satisfaction",
  main="Life Expectancy and Life Satisfaction, 2025",
  pch=16,
  cex=0.65,
  col="black",
  ylim=c(3, 8.3)
)

top_country <- which.max(hpi_2025$`Life Satisfaction`)

points(
  hpi_2025$`Life Expectancy`[top_country],
  hpi_2025$`Life Satisfaction`[top_country],
  pch=16,
  cex=1.2,
  col="firebrick3"
)

text(
  hpi_2025$`Life Expectancy`[top_country],
  hpi_2025$`Life Satisfaction`[top_country],
  labels=hpi_2025$Country[top_country],
  pos=2,
  offset=0.8,
  col="firebrick3",
  font=2,
  cex=0.9
)


# 11. mtext()

par(mar=c(5, 4, 4, 2) + 0.1)

plot(
  hpi_2025$`Life Expectancy`,
  hpi_2025$`Life Satisfaction`,
  xlab="Life Expectancy",
  ylab="Life Satisfaction",
  main="Life Expectancy and Life Satisfaction, 2025",
  pch=16,
  cex=0.65
)

mtext(
  "Happy Planet Index data, 2025",
  side=1,
  line=4,
  cex=0.8
)


# 12. legend()

plot(
  hpi_2025$`Life Expectancy`,
  hpi_2025$`Life Satisfaction`,
  xlab="Life Expectancy",
  ylab="Life Satisfaction",
  main="Life Expectancy and Life Satisfaction, 2025",
  pch=1
)

high_life <- hpi_2025$`Life Expectancy` >= 80

points(
  hpi_2025$`Life Expectancy`[high_life],
  hpi_2025$`Life Satisfaction`[high_life],
  pch=16
)

legend(
  "topleft",
  legend=c(
    "Life Expectancy < 80",
    "Life Expectancy >= 80"
  ),
  pch=c(1, 16),
  bty="n"
)