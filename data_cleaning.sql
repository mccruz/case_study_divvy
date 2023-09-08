CREATE TABLE cleaned_data AS

WITH bike_data AS 
	(
	SELECT *
	FROM "2022_08-2023_07"
	),

-- Check for duplicate entries. None found.
dup_check AS
	(
	SELECT 
		ride_id, 
		rideable_type, 
		started_at, 
		ended_at, 
		start_station_name, 
		start_station_id,
		end_station_name,
		end_station_id,
		start_lat,
		start_lng,
		end_lat,
		end_lng,
		member_casual,
		COUNT (*) AS Count
	FROM bike_data
	GROUP BY 
		ride_id, 
		rideable_type, 
		started_at, 
		ended_at, 
		start_station_name, 
		start_station_id,
		end_station_name,
		end_station_id,
		start_lat,
		start_lng,
		end_lat,
		end_lng,
		member_casual
	HAVING COUNT(*) > 1
	ORDER BY ride_id
	),




/*  

Determine if there are any NULL values in the data.
Results show start_station_name, end_station_name, start_station_id, end_station_id,
end_lat, and end_lng have NULL values. 

*/

count_null_values AS 
	(
	SELECT 
		count(case when ride_id is null then 1 end) as ride_id_count,
		count(case when rideable_type is null then 1 end) as rideable_type_count,
		count(case when started_at is null then 1 end) as started_at_count,
		count(case when ended_at is null then 1 end) as ended_at_count,
		count(case when start_station_name is null then 1 end) as start_station_name_count,
		count(case when start_station_id is null then 1 end) as start_station_id_count,
		count(case when end_station_name is null then 1 end) as end_station_name_count,
		count(case when end_station_id is null then 1 end) as end_station_id_count,
		count(case when start_lat is null then 1 end) as start_lat_count,
		count(case when start_lng is null then 1 end) as start_lng_count,
		count(case when end_lat is null then 1 end) as end_lat_count,
		count(case when end_lng is null then 1 end) as end_lng_count,
		count(case when member_casual is null then 1 end) as member_casual_count
	FROM bike_data
	),

-- Count total number of rows that have null values.
	
count_tot_null_rows AS
	(
	SELECT
	count(*)
	
	FROM "2022_08-2023_07"

	WHERE start_station_name IS NULL
		OR start_station_id IS NULL
		OR end_station_name IS NULL
		OR end_station_id IS NULL
		OR end_lat IS NULL
		OR end_lng IS NULL
	),
	
/* 

Below query was modified multiple times to check pattern of NULL values in both start/end_station_name,
start/end)_station_id and start/end_lat/lng. 

*/

null_start_station AS 
	(
	SELECT *
	FROM bike_data
	WHERE start_station_name IS NULL 
	AND start_station_id IS NOT NULL
	LIMIT 10
	),

/*  

Result were: 
	If start/end_station_name IS NULL, start/end_station_id is also NULL.
	start/end_station_name may be NOT NULL but start/end_lat/lng may be NULL.
	start/end_station_name may be NULL while start/end_lat/lng is NOT NULL.
Per Divvy FAQ, bikes can be parked outside of docking stations. However, the customer will
be charged an out-of-station fee. This could be the reason for either start or end_station_name
to be NULL.  

Entries that don't have a reference point to where they started or ended (i.e. start/end_station_name/id or start/end_lat/lng),
should be removed since they are missing needed data.  

*/

data_w_endpts AS 
	(
	SELECT *
	FROM bike_data	
-- Entry should either have a end_station_name, id or both lat/lng.
	WHERE 	
		(
			end_station_name IS NOT NULL  
			OR end_station_id IS NOT NULL
			OR 	
			(
				end_lat IS NOT NULL
				AND end_lng IS NOT NULL
			)
		)

-- AND it should either have a start_station_name, id or both lat/lng.		
		AND 	
		(
		 	start_station_name IS NOT NULL
			OR start_station_id IS NOT NULL
			OR 	
			(
				start_lat IS NOT NULL
				AND start_lng IS NOT NULL
			)
		)
	),

/* 

There are 128,904 entries with 'docked bike'. It would be prudent to ask what this is, but for now, 
since focus is on trip data specifically, this will be removed. 

*/

-- Count
docked_bike_count AS
	(
	SELECT count(*)
	FROM "2022_08-2023_07"
	WHERE rideable_type = 'docked_bike'
	),
-- Remove 'docked_bike'
	
active_bikes AS 
	(
	SELECT *
	FROM data_w_endpts
	WHERE rideable_type <> 'docked_bike'
	),

-- For NULL start/end_station_name/id that have start/end_lat/lng, NULL will be replaced with "Out Of Station".

OOS_added AS
	(
	SELECT
		*,
		COALESCE (start_station_name, 'Out Of Station') AS start_station_name_1,
		COALESCE (start_station_id, 'Out Of Station') AS start_station_id_1,
		COALESCE (end_station_name, 'Out Of Station') AS end_station_name_1,
		COALESCE (end_station_id, 'Out Of Station') AS end_station_id_1
	FROM active_bikes
	),

/* 

From manually checking unique station names using a GROUP BY statement, we can see that some stations are attributed to testing, 
bike repair, specific directional locations within the same station, temporary locations, public city racks, city racks
and have an asterisk added to them. These stations need to be trimmed/adjusted. 

Note that there were vaccination sites set up as well at various stations. This will be removed assuming that those
who parked there were availing of vaccines and not those that regularly park there.

*/

-- Count number of rows with extra characters

count_extra_char AS
	(
	SELECT
	count(*)
	
	FROM "2022_08-2023_07"

	WHERE start_station_name ~ '\*$'
	OR start_station_name ~ ' N$'
	OR start_station_name ~ ' S$'
	OR start_station_name ~ ' E$'
	OR start_station_name ~ ' W$'
	OR start_station_name ~ ' NW$'
	OR start_station_name ~ ' SW$'
	OR start_station_name ~ ' - W$'
	OR start_station_name ~ ' - SE$'
	OR start_station_name ~ ' - SW$'
	OR start_station_name ~ ' - NW$'
	OR start_station_name ~ ' - NE$'
	OR start_station_name ~ ' - East$'
	OR start_station_name ~ ' - West$'
	OR start_station_name ~ ' - South$'
	OR start_station_name ~ ' - North$'
	OR start_station_name ~ ' - midblock$'
	OR start_station_name ~ ' - midblock south$'
	OR start_station_name ~ ' - south corner$'
	OR start_station_name ~ ' - north corner$'
	OR start_station_name ~ ' \(NU\)$'
	OR start_station_name ~ ' \(East\)$'
	OR start_station_name ~ ' \(east\)$'
	OR start_station_name ~ ' \(south\)$'
	OR start_station_name ~ ' \(Temp\)$'
	OR start_station_name ~ ' \(NEXT Apts\)$'
	OR start_station_name ~ '^City Rack - '
	
	OR end_station_name ~ '\*$'
	OR end_station_name ~ ' N$'
	OR end_station_name ~ ' S$'
	OR end_station_name ~ ' E$'
	OR end_station_name ~ ' W$'
	OR end_station_name ~ ' NW$'
	OR end_station_name ~ ' SW$'
	OR end_station_name ~ ' - W$'
	OR end_station_name ~ ' - SE$'
	OR end_station_name ~ ' - SW$'
	OR end_station_name ~ ' - NW$'
	OR end_station_name ~ ' - NE$'
	OR end_station_name ~ ' - East$'
	OR end_station_name ~ ' - West$'
	OR end_station_name ~ ' - South$'
	OR end_station_name ~ ' - North$'
	OR end_station_name ~ ' - midblock$'
	OR end_station_name ~ ' - midblock south$'
	OR end_station_name ~ ' - south corner$'
	OR end_station_name ~ ' - north corner$'
	OR end_station_name ~ ' \(NU\)$'
	OR end_station_name ~ ' \(East\)$'
	OR end_station_name ~ ' \(east\)$'
	OR end_station_name ~ ' \(south\)$'
	OR end_station_name ~ ' \(Temp\)$'
	OR end_station_name ~ ' \(NEXT Apts\)$'
	OR end_station_name ~ '^City Rack - '
	),

-- Count rows used for vaccination sites, repair stations or testing.

other_station_check AS
	(
	SELECT
		count(*)
		
	FROM "2022_08-2023_07"
	
	WHERE start_station_name LIKE '%Vaccination Site'
		OR start_station_name LIKE '%REPAIR MOBILE STATION'
		OR start_station_name LIKE '% - TESTING'
		OR start_station_name LIKE '% - Test'
		OR end_station_name LIKE '%Vaccination Site'
		OR end_station_name LIKE '%REPAIR MOBILE STATION'
		OR end_station_name LIKE '% - TESTING'
		OR end_station_name LIKE '% - Test'
	),

	
-- Trim	

first_check_station_names AS 
	(
	SELECT 
		*,
		CASE
			WHEN start_station_name_1 ~ '\*$' THEN REGEXP_REPLACE(start_station_name_1, '\*$', '')
			WHEN start_station_name_1 ~ ' N$' THEN REGEXP_REPLACE(start_station_name_1, ' N$', '')
			WHEN start_station_name_1 ~ ' S$' THEN REGEXP_REPLACE(start_station_name_1, ' S$', '')
			WHEN start_station_name_1 ~ ' E$' THEN REGEXP_REPLACE(start_station_name_1, ' E$', '')
			WHEN start_station_name_1 ~ ' W$' THEN REGEXP_REPLACE(start_station_name_1, ' W$', '')
			WHEN start_station_name_1 ~ ' NW$' THEN REGEXP_REPLACE(start_station_name_1, ' NW$', '')
			WHEN start_station_name_1 ~ ' SW$' THEN REGEXP_REPLACE(start_station_name_1, ' SW$', '')
			WHEN start_station_name_1 ~ ' - W$' THEN REGEXP_REPLACE(start_station_name_1, ' - W$', '')		
			WHEN start_station_name_1 ~ ' - SE$' THEN REGEXP_REPLACE(start_station_name_1, ' - SE$', '')
			WHEN start_station_name_1 ~ ' - SW$' THEN REGEXP_REPLACE(start_station_name_1, ' - SW$', '')
			WHEN start_station_name_1 ~ ' - NW$' THEN REGEXP_REPLACE(start_station_name_1, ' - NW$', '')
			WHEN start_station_name_1 ~ ' - NE$' THEN REGEXP_REPLACE(start_station_name_1, ' - NE$', '')		
			WHEN start_station_name_1 ~ ' - East$' THEN REGEXP_REPLACE(start_station_name_1, ' - East$', '')
			WHEN start_station_name_1 ~ ' - West$' THEN REGEXP_REPLACE(start_station_name_1, ' - West$', '')
			WHEN start_station_name_1 ~ ' - South$' THEN REGEXP_REPLACE(start_station_name_1, ' - South$', '')
			WHEN start_station_name_1 ~ ' - North$' THEN REGEXP_REPLACE(start_station_name_1, ' - North$', '')
			WHEN start_station_name_1 ~ ' - midblock$' THEN REGEXP_REPLACE(start_station_name_1, ' - midblock$', '')
			WHEN start_station_name_1 ~ ' - midblock south$' THEN REGEXP_REPLACE(start_station_name_1, ' - midblock south$', '')
			WHEN start_station_name_1 ~ ' - south corner$' THEN REGEXP_REPLACE(start_station_name_1, ' - south corner$', '')
			WHEN start_station_name_1 ~ ' - north corner$' THEN REGEXP_REPLACE(start_station_name_1, ' - north corner$', '')
			WHEN start_station_name_1 ~ ' \(NU\)$' THEN REGEXP_REPLACE(start_station_name_1, ' \(NU\)$', '')		
			WHEN start_station_name_1 ~ ' \(East\)$' THEN REGEXP_REPLACE(start_station_name_1, ' \(East\)$', '')
			WHEN start_station_name_1 ~ ' \(east\)$' THEN REGEXP_REPLACE(start_station_name_1, ' \(east\)$', '')
			WHEN start_station_name_1 ~ ' \(south\)$' THEN REGEXP_REPLACE(start_station_name_1, ' \(south\)$', '')
			WHEN start_station_name_1 ~ ' \(Temp\)$' THEN REGEXP_REPLACE(start_station_name_1, ' \(Temp\)$', '')
			WHEN start_station_name_1 ~ ' \(NEXT Apts\)$' THEN REGEXP_REPLACE(start_station_name_1, ' \(NEXT Apts\)$', '')
			WHEN start_station_name_1 ~ '^City Rack - ' THEN REGEXP_REPLACE(start_station_name_1, '^City Rack - ', '')
		ELSE start_station_name_1
    	END AS start_station_name_2,
		CASE
			WHEN end_station_name_1 ~ '\*$' THEN REGEXP_REPLACE(end_station_name_1, '\*$', '')
			WHEN end_station_name_1 ~ ' N$' THEN REGEXP_REPLACE(end_station_name_1, ' N$', '')
			WHEN end_station_name_1 ~ ' S$' THEN REGEXP_REPLACE(end_station_name_1, ' S$', '')
			WHEN end_station_name_1 ~ ' E$' THEN REGEXP_REPLACE(end_station_name_1, ' E$', '')
			WHEN end_station_name_1 ~ ' W$' THEN REGEXP_REPLACE(end_station_name_1, ' W$', '')
			WHEN end_station_name_1 ~ ' NW$' THEN REGEXP_REPLACE(end_station_name_1, ' NW$', '')
			WHEN end_station_name_1 ~ ' SW$' THEN REGEXP_REPLACE(end_station_name_1, ' SW$', '')
			WHEN end_station_name_1 ~ ' - W$' THEN REGEXP_REPLACE(end_station_name_1, ' - W$', '')		
			WHEN end_station_name_1 ~ ' - SE$' THEN REGEXP_REPLACE(end_station_name_1, ' - SE$', '')
			WHEN end_station_name_1 ~ ' - SW$' THEN REGEXP_REPLACE(end_station_name_1, ' - SW$', '')
			WHEN end_station_name_1 ~ ' - NW$' THEN REGEXP_REPLACE(end_station_name_1, ' - NW$', '')
			WHEN end_station_name_1 ~ ' - NE$' THEN REGEXP_REPLACE(end_station_name_1, ' - NE$', '')		
			WHEN end_station_name_1 ~ ' - East$' THEN REGEXP_REPLACE(end_station_name_1, ' - East$', '')
			WHEN end_station_name_1 ~ ' - West$' THEN REGEXP_REPLACE(end_station_name_1, ' - West$', '')
			WHEN end_station_name_1 ~ ' - South$' THEN REGEXP_REPLACE(end_station_name_1, ' - South$', '')
			WHEN end_station_name_1 ~ ' - North$' THEN REGEXP_REPLACE(end_station_name_1, ' - North$', '')
			WHEN end_station_name_1 ~ ' - midblock$' THEN REGEXP_REPLACE(end_station_name_1, ' - midblock$', '')
			WHEN end_station_name_1 ~ ' - midblock south$' THEN REGEXP_REPLACE(end_station_name_1, ' - midblock south$', '')
			WHEN end_station_name_1 ~ ' - south corner$' THEN REGEXP_REPLACE(end_station_name_1, ' - south corner$', '')
			WHEN end_station_name_1 ~ ' - north corner$' THEN REGEXP_REPLACE(end_station_name_1, ' - north corner$', '')
			WHEN end_station_name_1 ~ ' \(NU\)$' THEN REGEXP_REPLACE(end_station_name_1, ' \(NU\)$', '')		
			WHEN end_station_name_1 ~ ' \(East\)$' THEN REGEXP_REPLACE(end_station_name_1, ' \(East\)$', '')
			WHEN end_station_name_1 ~ ' \(east\)$' THEN REGEXP_REPLACE(end_station_name_1, ' \(east\)$', '')
			WHEN end_station_name_1 ~ ' \(south\)$' THEN REGEXP_REPLACE(end_station_name_1, ' \(south\)$', '')
			WHEN end_station_name_1 ~ ' \(Temp\)$' THEN REGEXP_REPLACE(end_station_name_1, ' \(Temp\)$', '')
			WHEN end_station_name_1 ~ ' \(NEXT Apts\)$' THEN REGEXP_REPLACE(end_station_name_1, ' \(NEXT Apts\)$', '')
			WHEN end_station_name_1 ~ '^City Rack - ' THEN REGEXP_REPLACE(end_station_name_1, '^City Rack - ', '')
		ELSE end_station_name_1
    	END AS end_station_name_2
		
	FROM OOS_added
	WHERE start_station_name NOT LIKE '%Vaccination Site'
	AND start_station_name NOT LIKE '%REPAIR MOBILE STATION'
	AND start_station_name NOT LIKE '% - TESTING'
	AND start_station_name NOT LIKE '% - Test'
	AND end_station_name NOT LIKE '%Vaccination Site'
	AND end_station_name NOT LIKE '%REPAIR MOBILE STATION'
	AND end_station_name NOT LIKE '% - TESTING'
	AND end_station_name NOT LIKE '% - Test'

	),
		
/* 

Some entries had two strings of characters that needed to be removed such as " - SW" at the end of the string and 
"Public Rack - " at the beginning of the string. The above makes a first pass to remove instances while below 
makes a second pass to remove unwanted characters not caught in the first pass.

*/

second_check_station_names AS
	(
	SELECT
		*,
		CASE
			WHEN start_station_name_2 ~ '^Public Rack - ' THEN REGEXP_REPLACE(start_station_name_2, '^Public Rack - ', '')
			ELSE start_station_name_2 
			END AS start_station_name_3,
		CASE
			WHEN end_station_name_2 ~ '^Public Rack - ' THEN REGEXP_REPLACE(end_station_name_2, '^Public Rack - ', '')
			ELSE end_station_name_2 
			END AS end_station_name_3

	FROM first_check_station_names
	),

-- Extract month, day of week, hour, minutes and duration of ride.

date_extraction AS 
	(
	SELECT 
		*,
	CASE EXTRACT(DOW FROM started_at) 
		  WHEN 0 THEN 'SUN'
		  WHEN 1 THEN 'MON'
		  WHEN 2 THEN 'TUES'
		  WHEN 3 THEN 'WED'
		  WHEN 4 THEN 'THURS'
		  WHEN 5 THEN 'FRI'
		  WHEN 6 THEN 'SAT'    
		END AS day_of_week,
		CASE EXTRACT(MONTH FROM started_at)
		  WHEN 1 THEN 'JAN'
		  WHEN 2 THEN 'FEB'
		  WHEN 3 THEN 'MAR'
		  WHEN 4 THEN 'APR'
		  WHEN 5 THEN 'MAY'
		  WHEN 6 THEN 'JUN'
		  WHEN 7 THEN 'JUL'
		  WHEN 8 THEN 'AUG'
		  WHEN 9 THEN 'SEP'
		  WHEN 10 THEN 'OCT'
		  WHEN 11 THEN 'NOV'
		  WHEN 12 THEN 'DEC'
		END AS month,
		EXTRACT(HOUR FROM started_at) AS start_hour,
		EXTRACT(HOUR FROM ended_at) AS end_hour,
		ROUND(
		(EXTRACT(HOUR FROM ended_at) * 60 +
		EXTRACT(MINUTE FROM ended_at) +
		EXTRACT(SECOND FROM ended_at) / 60) 
		-
		(EXTRACT(HOUR FROM started_at) * 60 +
		EXTRACT(MINUTE FROM started_at) +
		EXTRACT(SECOND FROM started_at) / 60)
		,2) AS trip_duration_minutes

	FROM second_check_station_names
	),

-- Total count of rows with trip duration of <1min.

count_trip_less_1m AS
	(
	SELECT 
	count (*)
	FROM date_extraction
	WHERE trip_duration_minutes < 1
	)
	
-- Removal of rides that are <1min.

rm_less_1m AS
	(
	SELECT *
	FROM date_extraction
	WHERE trip_duration_minutes > 1
	)

-- Count of top stations
count_top_stations AS
	(
	SELECT 
	start_station_name_3,
	count(start_station_name_3) AS count_station
	FROM rm_less_1m
	GROUP BY start_station_name_3
	ORDER BY count_station DESC
	)	

-- Top stations. Edit "start_station_name_3" to end station as needed.
top_stations AS
	(
	SELECT 
	start_station_name_3,
	count(start_station_name_3) AS count_station
	
	FROM rm_less_1m
	GROUP BY start_station_name_3
	ORDER BY count_station DESC
	LIMIT 10
	)	
	
-- Cleaned data

	SELECT *
	FROM rm_less_1m
