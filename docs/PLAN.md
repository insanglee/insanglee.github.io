# Final Project Plan

## 1. Question

This project examines how subway ridership and arrest patterns vary across New York City subway stations and over time.

Our main question is:

**How do subway ridership and arrest patterns vary across stations and over time, and how do patterns change after accounting for passenger volume?**

The intended audience includes transportation planners, public safety professionals, researchers, and members of the public interested in subway activity and public safety.

## 2. Data

We will combine two public datasets:

- **MTA Subway Hourly Ridership Data**
- **NYPD Arrest Data**

The final project is planned to cover **2020–2024**, with the main unit of observation defined as **station × month**.

For **Assignment 8**, the dashboard prototype uses **2024 data for nine selected high-ridership subway station complexes** in Manhattan, Queens, and Brooklyn. This smaller subset allows us to build and test the dashboard structure before expanding the analysis to the full subway network and the full 2020–2024 period.

The MTA dataset provides subway ridership, station complex information, borough, and station coordinates.

The NYPD dataset provides arrest dates, offense information, borough, and arrest coordinates.

For the Assignment 8 prototype, each arrest is assigned to the nearest selected subway station when the arrest occurred within **500 meters** of that station.

Key variables include:

- Monthly subway ridership
- Monthly arrest count
- Arrests per 100,000 riders
- Station complex
- Borough
- Month
- Offense type
- Latitude and longitude

Ridership and arrest measures vary over time, allowing us to examine temporal trends as well as differences across subway stations.

## 3. Charts

### Chart 1: Monthly Time-Series Line Chart  
**Abela Thought-Starter #6 — Line Chart**

This chart will show monthly changes in subway ridership and arrest measures during 2024, making it appropriate for identifying trends and possible seasonal patterns over time.

### Chart 2: Station-Level Scatter Plot  
**Abela Thought-Starter #9 — Scatter Chart**

This chart will show the relationship between station-level ridership and arrests per 100,000 riders, helping identify stations that differ from the overall pattern.

### Chart 3: Ridership-Adjusted Bubble Chart  
**Abela Thought-Starter #18 — Bubble Chart**

This chart will compare station-level arrest counts and arrest rates while using bubble size to represent passenger volume. This allows three variables to be examined simultaneously.

A geographic station map may also be added as a supplemental visualization in the final project.

## 4. Interaction

The Assignment 8 dashboard will include interactive features that allow users to:

- Hover over chart elements to view station-level information
- Use a range selector to focus on specific months in the time-series chart
- Search and sort the station-level data table
- Compare ridership, raw arrest counts, and arrests per 100,000 riders across stations

Additional filtering by station, borough, month, or offense type may be added as the dashboard becomes fully reactive in the next stage of the project.

## 5. Deployment

The dashboard will be developed as a **Quarto dashboard** and published on the project website through **GitHub Pages**.

Quarto is appropriate for the Assignment 8 prototype because it supports dashboard layouts, interactive R visualizations, and direct integration with the existing website.

The dashboard can later be extended with additional Shiny reactivity and deployed through **Posit Connect Cloud or Shinylive** as the final project develops.