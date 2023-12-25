########################
### Data Exploration ###
########################

app_checkpoints <- read.csv("data/application-checkpoints.csv", header = TRUE)
gpu <- read.csv("data/gpu.csv", header = TRUE)
task_x_y <- read.csv("data/task-x-y.csv", header = TRUE)

##########################
### Data Preprocessing ###
##########################


# OBJECTIVE 1
################################################################################

# Convert timestamp to datetime 
app_checkpoints$timestamp <- as.POSIXct(app_checkpoints$timestamp, 
                                        format="%Y-%m-%dT%H:%M:%OSZ")

# Function to process events
process_event <- function(event_name, event_type, checkpoints_data) {
  # Filter rows based on the specified event name and type
  event_df <- checkpoints_data %>%
    filter(eventName == event_name & eventType %in% event_type)
  
  # Merge rows with 'START' and 'STOP' eventType based on 'taskId'
  merged_df <- left_join(event_df %>% filter(eventType == "START"),
                         event_df %>% filter(eventType == "STOP"),
                         by = 'taskId', relationship = "many-to-many")
  
  # Calculate runtime in seconds by finding the time difference between 'STOP' and 'START'
  runtime_df <- merged_df %>%
    mutate(Runtime = as.numeric(difftime(timestamp.y, timestamp.x, units = "secs")))
  
  # Remove unnecessary columns
  cleaned_df <- runtime_df %>%
    select(-c(hostname.y, jobId.y, jobId.x, eventName.y))
  
  # Rename columns for clarity
  renamed_df <- cleaned_df %>%
    rename(
      hostname = hostname.x,
      eventName = eventName.x,
      time_start = timestamp.x,
      time_stop = timestamp.y,
      eventType_Start = eventType.x,
      eventType_Stop = eventType.y
    )
  
  # Select relevant columns, ensuring unique rows based on 'taskId'
  final_df <- renamed_df %>%
    select(taskId, hostname, everything()) %>%
    distinct(taskId, hostname, .keep_all = TRUE)
  
  # Return the final processed dataframe
  return(final_df)
}

# List of events and their types
events_list <- list(
  c("Tiling", "START", "STOP"),
  c("Saving Config", "START", "STOP"),
  c("Render", "START", "STOP"),
  c("TotalRender", "START", "STOP"),
  c("Uploading", "START", "STOP")
)

# Initialize an empty dataframe
Events_Final <- data.frame()

# Process events and combine dataframes
for (event in events_list) {
  event_name <- event[1]
  
  # Process the event and append the resulting dataframe to Events_Final
  Events_Final <- bind_rows(Events_Final, process_event(event[1], event[2:3],
                                                        app_checkpoints))
}


# OBJECTIVE 2
################################################################################

# Convert timestamp to datetime 
gpu$timestamp <- as.POSIXct(gpu$timestamp, format="%Y-%m-%dT%H:%M:%OSZ")

# Create a dataframe with the mean Performance of each temperature
mean_utilization <- gpu %>%
  group_by(gpuTempC) %>%
  summarize(
    mean_gpuUtilPerc = mean(gpuUtilPerc, na.rm = TRUE),
    mean_gpuMemUtilPerc = mean(gpuMemUtilPerc, na.rm = TRUE)
  )

# Rename timestamp to time_start in the gpu dataset for join
gpu_obj2 <- gpu %>% rename(time_start = timestamp)

# Join datasets based on time_start
Final_Dataset <- left_join(gpu_obj2, Events_Final, by = c("time_start"), 
                           relationship = "many-to-many")

# Exclude TotalRender from the events
events_to_exclude <- c("TotalRender")
filtered_events <- Final_Dataset %>%
  filter(!eventName %in% events_to_exclude) %>%
  na.omit()  # Remove rows with NA values, consider the impact

mean_events_utilization <- filtered_events %>%
  group_by(eventName, gpuTempC) %>%
  summarize(
    mean_gpuUtilPerc = mean(gpuUtilPerc, na.rm = TRUE),
    mean_gpuMemUtilPerc = mean(gpuMemUtilPerc, na.rm = TRUE)
    , .groups = 'drop') %>%
  filter(eventName %in% c("Tiling", "Saving Config", "Render", "Uploading"))


# OBJECTIVE 3
################################################################################

# Create a new column for Performance
gpu <- gpu %>% mutate(Performance = ((gpuUtilPerc * powerDrawWatt) + 
                                       (gpuMemUtilPerc * powerDrawWatt)) / 100)

# Create a DataFrame with Mean Performance and Standard Deviation
mean_Performance <- gpu %>%
  group_by(gpuSerial) %>%
  summarize(
    mean_Performance = mean(Performance, na.rm = TRUE),
    sd_Performance = sd(Performance, na.rm = TRUE))

# Find the top 3 serial numbers
top_3_serials <- mean_Performance %>% top_n(3, wt = mean_Performance)

# Find the worst 3 serial numbers
worst_3_serials <- mean_Performance %>% top_n(-3, wt = mean_Performance)

# Filter the GPU dataset for the top 3 serials
top_3_data <- gpu %>% filter(gpuSerial %in% top_3_serials$gpuSerial)

# Filter the GPU dataset for the worst 3 serials
worst_3_data <- gpu %>% filter(gpuSerial %in% worst_3_serials$gpuSerial)

# Round down timestamps to the nearest minute
top_3_data <- top_3_data %>%
  mutate(time_minute = floor_date(timestamp, unit = "minute")) %>%
  group_by(time_minute, gpuSerial) %>%
  summarize(
    mean_Performance = mean(Performance, na.rm = TRUE), .groups = "drop")

worst_3_data <- worst_3_data %>%
  mutate(time_minute = floor_date(timestamp, unit = "minute")) %>%
  group_by(time_minute, gpuSerial) %>%
  summarize(
    mean_Performance = mean(Performance, na.rm = TRUE), .groups = "drop")

################################################################################

#################################
### OBJECTIVE 1 VISUALISATION ###
#################################

# Box plot of the events
Events_Boxplot <- ggplot(Events_Final, aes(x = eventName, y = Runtime)) +
  geom_boxplot(fill = "#4E79A7", color = "black") +
  labs(
    title = "Runtime of Each Event",
    x = "Event",
    y = "Runtime (seconds)"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))

Events_Barplot <- ggplot(Events_Final %>% filter(eventName != "TotalRender"), 
                         aes(x = eventName, y = Runtime)) +
  stat_summary(fun = "median", geom = "bar", fill = "#4E79A7", color = "black") +
  geom_text(stat = 'summary', fun = median, aes(label = sprintf("%.3g", after_stat(y))), vjust = -0.5) +
  labs(
    title = "Runtime of Each Event (excluding TotalRender)",
    x = "Event",
    y = "Runtime (seconds)"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))


#################################
### OBJECTIVE 2 VISUALISATION ###
#################################

# Line plot of overall Performance
Overall_Performance_Temp <- ggplot(mean_utilization, aes(x = gpuTempC)) +
  geom_line(aes(y = mean_gpuUtilPerc, color = "GPU Utilization"), linewidth = 1) +
  geom_line(aes(y = mean_gpuMemUtilPerc, color = "GPU-Memory Utilization"), 
            linewidth = 1) +
  labs(
    title = "Interplay of Performance and Temperature",
    x = "Temperature (°C)",
    y = "Mean Utilization (%)",
    color = "Metric"
  ) +
  scale_color_manual(values = c("GPU Utilization" = "#4E79A7", 
                                "GPU-Memory Utilization" = "#E15759")) +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 10)) +
  theme_minimal()+
  theme(legend.position = "top",
        legend.justification = "left",
        legend.title = element_blank())


# Line plot of all events
Events_Performance_Temp_Plot <- ggplot(mean_events_utilization , aes(x = gpuTempC)) +
  geom_line(aes(y = mean_gpuUtilPerc, color = "GPU Utilization"), linewidth = 1) +
  geom_line(aes(y = mean_gpuMemUtilPerc, color = "GPU-Memory Utilization"), 
            linewidth = 1) +
  labs(
    title = "Interplay of Performance and Temperature Across Events",
    x = "Temperature (°C)",
    y = "Mean Utilization (%)"
  ) +
  scale_color_manual(values = c("GPU Utilization" = "#4E79A7", 
                                "GPU-Memory Utilization" = "#E15759")) +
  facet_grid(eventName ~ ., scales = "free_y") +
  theme_minimal() +
  theme(
    legend.position = "top", 
    legend.justification = "left",  
    legend.title = element_blank()
  )

#################################
### OBJECTIVE 3 VISUALISATION ###
#################################

# Plotting scatter plot for the top 3 serials
top_3_scatter <- ggplot(top_3_serials, aes(x = as.factor(gpuSerial), 
                                           y = mean_Performance, 
                                           color = as.factor(gpuSerial))) +
  geom_point(size = 2) +
  labs(
    title = "Scatter Plot of Fastest 3 GPU Serial Numbers",
    x = "Serial Number",
    y = "Mean Performance"
  ) +
  scale_y_continuous(limits = c(128, 140), breaks = seq(128, 140, 3)) + 
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 0, hjust = 0.5, vjust = 0.5),
    legend.position = "none",
    axis.title.x = element_text(vjust = -2),
    axis.title.y = element_text(vjust = 2)
  ) +
  scale_color_manual(values = c("#4E79A7", "#F28E2B", "#E15759"))

# Plotting scatter plot for the worst 3 serials
worst_3_scatter <- ggplot(worst_3_serials, aes(x = as.factor(gpuSerial), 
                                               y = mean_Performance,
                                               color = as.factor(gpuSerial))) +
  geom_point(size = 2) +
  labs(
    title = "Scatter Plot of Slowest 3 GPU Serial Numbers",
    x = "Serial Number",
    y = "Mean Performance"
  ) +
  theme_minimal() +
  scale_y_continuous(limits = c(92, 93.5), breaks = seq(92, 93.5, 0.3)) + 
  theme(
    axis.text.x = element_text(angle = 0, hjust = 0.5, vjust = 0.5),
    legend.position = "none",
    axis.title.x = element_text(vjust = -2),
    axis.title.y = element_text(vjust = 2)
  ) +
  scale_color_manual(values = c("#4E79A7", "#F28E2B", "#E15759"))


# Create the line plot for top_3_data
top_3_line <- ggplot(top_3_data, aes(x = time_minute, y = mean_Performance, 
                                     color = as.factor(gpuSerial))) +
  geom_line() +
  geom_point(aes(color = as.factor(gpuSerial)), size = 1) +
  labs(
    title = "Performance of Top 3 GPU Serial Numbers Over Time",
    x = "Time",
    y = "Mean Performance"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 0, hjust = 0.5, vjust = 0.5),
    legend.position = "top",
    axis.title.x = element_text(vjust = -2),
    axis.title.y = element_text(vjust = 2)
  ) +
  scale_color_manual(values = c("#4E79A7", "#F28E2B", "#E15759"), name = NULL)


# Create the line plot for worst_3_data
worst_3_line <- ggplot(worst_3_data, aes(x = time_minute, y = mean_Performance, 
                                         color = as.factor(gpuSerial))) +
  geom_line() +
  geom_point(aes(color = as.factor(gpuSerial)), size = 1) +
  labs(
    title = "Performance of Worst 3 GPU Serial Numbers Over Time",
    x = "Time",
    y = "Mean Performance"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 0, hjust = 0.5, vjust = 0.5),
    legend.position = "top",
    axis.title.x = element_text(vjust = -2),
    axis.title.y = element_text(vjust = 2)
  ) +
  scale_y_continuous(labels = scales::comma) +
  scale_color_manual(values = c("#4E79A7", "#F28E2B", "#E15759"), name = NULL)