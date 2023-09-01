
WITH bike_data AS 
	(
	SELECT *
	FROM "2022_08-2023_07"
	),

-- Checked for duplicate entries. None found.
  
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
Results showed start_station_name, end_station_name, start_station_id, end_station_id, end_lat, and end_lng had NULL values. 

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
	- If start/end_station_name IS NULL, start/end_station_id is also NULL.
	- start/end_station_name may NOT BE NULL but start/end_lat/lng may be NULL.
	- start/end_station_name may be NULL while start/end_lat/lng may NOT BE NULL.
Per Divvy FAQ, bikes can be parked outside of docking stations. However, the customer will
be charged an out-of-station fee. This could be the reason for either start or end_station_name
to be NULL.  Divvy FAQ: https://help.divvybikes.com/hc/en-us

Entries that don't have a reference point to where they started or ended (i.e. start/end_station_name/id or start/end_lat/lng),
were removed since they were missing needed data.  

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

There were 128,904 entries with 'docked bike'. It would be prudent to ask what this is, 
but for now, since focus is on trip data specifically, these were removed. 

*/

active_bikes AS 
	(
	SELECT *
	FROM data_w_endpts
	WHERE rideable_type <> 'docked_bike'
	),

-- For NULL start/end_station_name/id that have start/end_lat/lng, NULL was replaced with "Out Of Station".

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
bike repair, specific directional locations of specific stations, temporary locations, public racks, city racks
and have an asterisk added to them. These stations were trimmed/adjusted. 

Note that there were vaccination sites set up as well at various stations. These were removed, assuming that users
who parked bikes there were availing of vaccines.

*/


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
    	END AS start_station_name_2
		
	FROM OOS_added
	WHERE start_station_name NOT LIKE '%Vaccination Site'
	AND start_station_name NOT LIKE '%REPAIR MOBILE STATION'
	AND start_station_name NOT LIKE '% - TESTING'
	AND start_station_name NOT LIKE '% - Test'

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
			END AS start_station_name_3

	FROM first_check_station_names
),

-- Extracted month, day of week, hour, minutes and duration of ride.

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

-- Removed rides that were less than 1 minute.

rm_less_1m AS
	(
	SELECT *
	FROM date_extraction
	WHERE trip_duration_minutes > 1
	)

-- Clean data.

	SELECT count(*)
	FROM rm_less_1m
