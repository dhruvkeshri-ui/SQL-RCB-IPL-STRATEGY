USE ipl

-- OBJECTIVE QUESTION 

-- Q1. List the different dtypes of columns in table “ball_by_ball” (using information schema)

SELECT COLUMN_NAME,DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME="ball_by_ball";


-- By reviewing the data types and nullability of the specified columns,
-- one can assess the design of the ball_by_ball table and its suitability for storing detailed cricket match data.

-- 	Q2. What is the total number of runs scored in 1st season by RCB (bonus: also include the extra runs using the extra runs table)

select Season_Id, Season_Year 
from Season
order by Season_Id;

Select sum(b.Runs_Scored + coalesce(e.Extra_Runs, 0)) AS Total_Runs
from ball_by_ball b
join matches m on b.Match_Id = m.Match_Id
join team t on b.Team_Batting = t.Team_Id
left join extra_runs e ON b.Match_Id = e.Match_Id 
 and b.Over_Id = e.Over_Id 
 and b.Ball_Id = e.Ball_Id 
 and b.Innings_No = e.Innings_No
where m.Season_Id = 6
and t.Team_Name = "Royal Challengers Bangalore";   

 
--  The query effectively calculates the total runs scored by RCB in the first season, including both regular runs and extra runs. 
-- This comprehensive approach ensures that all contributions to the team's score are accounted for, providing a complete picture of their performance in that season.
 
--  Q3. How many players were more than the age of 25 during season 2014?

Select count(distinct pm.Player_id ) as PLAYER_OVER_25
from  Matches m 
join Player_Match pm on m.Match_ID = pm.Match_ID
join Player p on pm.Player_Id = p.Player_Id
where m.Season_Id = 7
and timestampdiff(Year, p.DOB, m.Match_Date) > 25;

-- This query counts the number of distinct players over the age of 25 during the 2014 season by calculating their age based on their date of birth (DOB) as of January 1, 2014. 
-- This information can help assess the team's experience level and inform future recruitment strategies.

--  Q4. How many matches did RCB win in 2013? 

SELECT COUNT(*) AS TOTAL_WIN_BY_RCB_2013
FROM matches                  
WHERE Match_Winner=2 AND YEAR(Match_Date)=2013;	


--  Q5. List the top 10 players according to their strike rate in the last 4 seasons

Select p.Player_Name, sum(b1.Runs_Scored) as Total_Run, count(*) as Balls_Faced,
    round(sum(b1.Runs_Scored) * 100.0 / count(*), 2) as Strike_Rate
from ball_by_ball b1
join matches m on b1.Match_Id = m.Match_Id
join season s on m.Season_Id = s.Season_Id
join player p on b1.Striker = p.Player_Id
where s.Season_Year >= (select max(Season_Year) - 3 from season)
group by p.Player_Name
order by Strike_Rate desc limit 10;


 -- This query identifies the top 10 players based on their strike rate over the last 4 seasons. It first retrieves the last 4 seasons, 
 -- then gathers match IDs from those seasons, calculates total runs and balls faced for each player, ranks them by strike rate, and finally selects the top 10 players with the highest strike rates.
 

--  Q6. What are the average runs scored by each batsman considering all the seasons?

SELECT p.Player_Name,SUM(Runs_Scored) AS Total_Runs,
       COUNT(DISTINCT Match_ID) AS Innings_Played,
       ROUND(SUM(Runs_Scored)/COUNT(DISTINCT Match_ID),2) AS BATTING_AVERAGE
FROM ball_by_ball b
JOIN player p
ON b.Striker=p.Player_ID
GROUP BY Player_Name
ORDER BY BATTING_AVERAGE DESC;		


-- This query calculates the average runs scored by each batsman across all seasons. It sums the total runs, 
-- counts distinct innings for each player, and computes the average runs per innings, providing a comprehensive view of each batsman's performance.
 
--  Q7. What are the average wickets taken by each bowler considering all the seasons

   -- Step 1: Identify total wickets taken by each bowler
with BowlerWickets as (select b.Bowler as Bowler_Id, count(w.Player_Out) as Total_Wickets
	from Wicket_Taken w
	join ball_by_ball b on w.Match_Id = b.Match_Id
     and w.Over_Id = b.Over_Id and w.Ball_Id = b.Ball_Id and w.Innings_No = b.Innings_No
    group by b.Bowler),

-- Step 2: Count the total number of seasons
TotalSeasons as (select count(distinct Season_Year) as Season_Count from Season)

-- Step 3: Calculate average wickets per season for each bowler
select bw.Bowler_Id, bw.Total_Wickets,
round(bw.Total_Wickets * 1.0 / ts.Season_Count, 2) as Average_Wickets_Per_Season
from BowlerWickets bw
cross join TotalSeasons ts
order by Average_Wickets_Per_Season desc;
	
-- This query calculates the average wickets taken by each bowler across all seasons. It first identifies the total wickets for each bowler, 
-- counts the total number of seasons,and then computes the average wickets per season, providing insights into each bowler's performance over time.


--  Q8. List all the players who have average runs scored greater than the overall average and who have taken wickets greater than the overall average.

with playerbattingstats as (
  select p.player_id, p.player_name, sum(bbb.runs_scored) as total_runs_scored
  from ball_by_ball bbb
  join player p on bbb.striker = p.player_id
  group by p.player_id, p.player_name),
playerdismissals as (
  select wt.player_out as player_id, count(*) as total_times_out
  from wicket_taken wt
  group by wt.player_out),
playerbattingaverage as (
  select s.player_id, s.player_name,
         case when coalesce(d.total_times_out,0) = 0 then null
              else (s.total_runs_scored) / d.total_times_out end as batting_avg
  from playerbattingstats s
  left join playerdismissals d on s.player_id = d.player_id),
playerbowlingstats as (
  select bb.bowler as player_id, count(*) as total_wickets
  from wicket_taken wt
  join ball_by_ball bb
    on bb.match_id  = wt.match_id
   and bb.innings_no = wt.innings_no
   and bb.over_id    = wt.over_id
   and bb.ball_id    = wt.ball_id
    join out_type ot on ot.out_id = wt.kind_out
 where  ot.out_name not  in ('caught','run out ','retired hurt','stumped','obstructing the field')
  group by bb.bowler),
overall as (
  select
    (select avg(batting_avg) from playerbattingaverage) as overall_batting_avg,
    (select avg(total_wickets) from playerbowlingstats) as overall_wickets_avg
)
select
  pba.player_id,
  pba.player_name,
  round(pba.batting_avg, 2) as batting_avg,
  pbs.total_wickets,
  round(o.overall_batting_avg, 2) as overall_batting_avg,
  round(o.overall_wickets_avg, 2) as overall_wickets_avg
from playerbattingaverage pba
join playerbowlingstats pbs on pba.player_id = pbs.player_id
cross join overall o
where pba.batting_avg > o.overall_batting_avg
  and pbs.total_wickets > o.overall_wickets_avg
order by pba.batting_avg desc, pbs.total_wickets desc;

-- This query lists players who have both an average runs scored greater than the overall average and total wickets taken greater than the overall average. 
-- It first calculates total wickets for each player, then determines the overall average wickets, and finally filters players based on these criteria.


--  Q9. Create a table rcb_record table that shows the wins and losses of RCB in an individual venue.

create table rcb_record (
    Venue_Id int not null,
    Venue_Name varchar(450) not null,
    Wins int default 0,
    Losses int default 0,
  primary key (Venue_Id));
insert into rcb_record (Venue_Id, Venue_Name, Wins, Losses)
select v.Venue_Id, v.Venue_Name,
    count(case when m.Match_Winner = 1 then 1 else null end) As Wins,  
    count(case when m.Match_Winner != 1 then 1 else null end) As Losses
from matches m
join Venue v ON m.Venue_Id = v.Venue_Id
where (m.Team_1 = 1 or m.Team_2 = 1)  
group by v.Venue_Id, v.Venue_Name;


-- This script creates a table named rcb_record to track the wins and losses of Royal Challengers Bangalore (RCB) at individual venues. 
-- It inserts data by counting wins and losses based on match results where RCB is either Team 1 or Team 2.

--  Q10. What is the impact of bowling style on wickets taken?

select bs.Bowling_skill, count(wt.Player_Out) as Wicket_taken
from ball_by_ball as bb
join wicket_taken as wt on bb.Match_Id = wt.Match_Id 
           and  bb.Innings_No = wt.Innings_No 
		   and bb.Over_Id = wt.Over_Id and bb.Ball_Id = wt.Ball_Id
join player as p on bb.Bowler = p.Player_Id
join bowling_style as bs on p.Bowling_skill = bs.Bowling_Id
group by bs.Bowling_skill;

-- This query analyzes the impact of bowling style on the number of wickets taken. It counts total wickets for each 
-- bowling style by joining the Wicket_Taken, Ball_by_Ball, and Bowling_Style tables, providing insights into which styles are most effective.

--  Q11. Write the SQL query to provide a status of whether the performance of the team is better than the previous year's performance on the basis of the number of runs scored by the team in the season and the number of wickets taken 

with team_runs as (select m.Season_Id, b.Team_Batting AS Team_Id, sum(b.Runs_Scored) as Total_Runs
from Ball_by_Ball b
join Matches m on b.Match_Id = m.Match_Id
group by m.Season_Id, b.Team_Batting),

team_wickets as (select m.Season_Id, b.Team_Bowling AS Team_Id, count(w.Player_Out) as Total_Wickets
from Ball_by_Ball b
join Matches m ON b.Match_Id = m.Match_Id
join Wicket_Taken w on b.Match_Id = w.Match_Id
and b.Over_Id = w.Over_Id
and b.Ball_Id = w.Ball_Id
and b.Innings_No = w.Innings_No
group by m.Season_Id, b.Team_Bowling),

combined as (select r.Season_Id, r.Team_Id, r.Total_Runs, w.Total_Wickets
from team_runs r
join team_wickets w on r.Season_Id = w.Season_Id and r.Team_Id = w.Team_Id),

with_previous as (
select c.*, s.Season_Year, lag(c.Total_Runs) over (partition by c.Team_Id order by s.Season_Year) as Prev_Total_Runs,
                           lag(c.Total_Wickets) over (partition by c.Team_Id order by s.Season_Year) as Prev_Total_Wickets
from combined c
join Season s on c.Season_Id = s.Season_Id)

select t.Team_Name, wp.Season_Year, wp.Total_Runs, wp.Total_Wickets, wp.Prev_Total_Runs, wp.Prev_Total_Wickets,
   CASE
    when wp.Total_Runs > wp.Prev_Total_Runs and wp.Total_Wickets > wp.Prev_Total_Wickets then 'Better'
    when wp.Total_Runs < wp.Prev_Total_Runs and wp.Total_Wickets < wp.Prev_Total_Wickets then 'Worse'
	else 'Same'
    end as Performance_Status
from with_previous wp
join Team t on wp.Team_Id = t.Team_Id
where wp.Prev_Total_Runs is not null and wp.Prev_Total_Wickets is not null
order by t.Team_Name, wp.Season_Year;


-- This query evaluates the performance of each team by comparing total runs scored and wickets taken in the current season against the previous season. 
-- It calculates total runs and wickets, combines the data, and determines if the performance is 'Better' or 'Worse' than the previous year.


--  Q12. Can you derive more KPIs for the team strategy?

--  Batting Performance KPIs:
select Team_Batting, avg(Runs_Scored) as Avg_Runs_Per_Over
from ball_by_ball
group by Team_Batting;

-- Run Rate in Powerplays vs. Middle and Death Overs:
select Team_Batting,
    avg(case when Over_Id <= 6 then Runs_Scored else 0 end) as Powerplay_Run_Rate,
    avg(case when Over_Id BETWEEN 7 and 15 then Runs_Scored else 0 end ) as Middle_Over_Run_Rate,
   avg(case when Over_Id > 15 then Runs_Scored else 0 end) as Death_Over_Run_Rate
from ball_by_ball
group by Team_Batting;

-- Boundary Percentage
select Team_Batting,
    (sum(case when Runs_Scored = 4 then 1 when Runs_Scored = 6 then 1 else 0 end) * 100) / count(*) as Boundary_Percentage
from ball_by_ball
group by Team_Batting;

-- Bowling Strategy KPIs:
-- Bowling Phase Strategy (Economy Rates in Different Phases):
select Team_Bowling,
    avg(case when Over_Id <= 6 then Runs_Scored else 0 end) as Powerplay_Economy_Rate,
   avg(case when Over_Id between 7 and 15 then Runs_Scored else 0 end) as Middle_Over_Economy_Rate,
    avg(case when Over_Id > 15 then Runs_Scored else 0 end) as Death_Over_Economy_Rate
from Ball_by_Ball
group by Team_Bowling;

-- Fielding Efficiency (Catches and Run Outs):
select Team_Batting, sum(case when Runs_Scored is null then 1 else 0 end) as Fielding_Efficiency
from ball_by_ball
group by Team_Batting;

-- Match strategy KPI's:
select Toss_Decide, count(*) as Number_of_Matches,
    sum(case when Match_Winner = Toss_Winner then 1 else 0 end) as  Matches_Won_After_Toss_Decision
from matches
group by Toss_Decide;

-- Batting Hand Strategy:
select Batting_hand, sum(Runs_Scored) as Total_Runs,
    count(distinct Player_Id) as Number_of_Batsmen
from Player
join Ball_by_Ball on Player.Player_Id = Ball_by_Ball.Striker
group by Batting_hand;
    
-- Extra Runs Strategy:
select sum(Extra_Runs) as Total_Extra_Runs
from Extra_Runs
where Match_Id in (select Match_Id from Matches where Team_1 = 1 or Team_2 = 1);  
    
    -- Win Margin Strategy:
 select Win_Type, avg(Win_Margin) as Avg_Win_Margin
from matches
group by Win_Type;
    
    -- Man of the Match Strategy:
 select Player_Name, count(*) as Number_of_Times_Man_of_the_Match
from matches
join Player on Matches.Man_of_the_Match = Player.Player_Id
group by Player_Name;
    
    -- This set of queries derives various Key Performance Indicators (KPIs) for team strategy, focusing on batting performance, bowling strategy, fielding efficiency, match strategy, and individual player contributions. 
    -- These KPIs provide insights into team strengths and areas for improvement.
        
    
--  Q13. Using SQL, write a query to find out the average wickets taken by each bowler in each venue. Also, rank the gender according to the average value.

with Bowler_Avg_Wickets as (select p.Player_Id, p.Player_Name, v.Venue_Name,
        count(wt.Player_Out) / count(distinct m.Match_Id) as Avg_Wickets
    from ball_by_ball bb
    join wicket_taken wt on bb.Match_Id = wt.Match_Id 
        and bb.Innings_No = wt.Innings_No 
        and bb.Over_Id = wt.Over_Id 
        and bb.Ball_Id = wt.Ball_Id
    join player p on bb.Bowler = p.Player_Id
    join matches m on bb.Match_Id = m.Match_Id
    join venue v on m.Venue_Id = v.Venue_Id
    group by p.Player_Id, p.Player_Name, v.Venue_Name)
select Player_Id, Player_Name, Venue_Name, Avg_Wickets,
    row_number() over (order by Avg_Wickets desc) as Wicket_Rank
from Bowler_Avg_Wickets
order by Wicket_Rank;

-- This query calculates the average wickets taken by each bowler at each venue. 
-- It ranks bowlers based on their average wickets per venue, providing insights into bowler performance in different locations.

--  Q14. Which of the given players have consistently performed well in past seasons? (will you use any visualization to solve the problem)

WITH Batting as (select p.Player_Id, p.Player_Name, s.Season_Year, sum(b.Runs_Scored) as Total_Runs
from Ball_by_Ball b
join Matches m on b.Match_Id = m.Match_Id
join Season s on m.Season_Id = s.Season_Id
join Player p on b.Striker = p.Player_Id
group by p.Player_Id, p.Player_Name, s.Season_Year
order by p.Player_Name, s.Season_Year),

Bowling as (select p.Player_Id, p.Player_Name, s.Season_Year, count(w.Player_Out) as Total_Wickets
from Ball_by_Ball b
join Wicket_Taken w on b.Match_Id = w.Match_Id
and b.Over_Id = w.Over_Id
and b.Ball_Id = w.Ball_Id
and b.Innings_No = w.Innings_No
join Matches m on b.Match_Id = m.Match_Id
join Season s on m.Season_Id = s.Season_Id
join Player p on b.Bowler = p.Player_Id
group by p.Player_Id, p.Player_Name, s.Season_Year
order by p.Player_Name, s.Season_Year)

select b.Player_Id, b.Player_Name, count(distinct b.Season_Year) as best_seasons
from (select Player_Id, Player_Name, Season_Year from Batting where Total_Runs > 400
      UNION ALL
      select Player_Id, Player_Name, Season_Year from Bowling where Total_Wickets > 15) b
group by b.Player_Id, b.Player_Name
having count(distinct b.Season_Year) >= 3
order by best_seasons desc;


--  Q15. Are there players whose performance is more suited to specific venues or conditions? (how would you present this using charts?) 

select p.Player_Name, v.Venue_Name, sum(b1.Runs_Scored) as Total_Runs, count(*) as Balls_Faced,
    round(sum(b1.Runs_Scored) * 1.0 / COUNT(*), 2) as Strike_Rate
from ball_by_ball b1
join matches m on b1.Match_Id = m.Match_Id
join venue v on m.Venue_Id = v.Venue_Id
join player p on b1.Striker = p.Player_Id
group by p.Player_Name, v.Venue_Name
order by p.Player_Name, Total_Runs desc;



-- SUBJECTIVE QUESTIONS

-- Q.1) How does the toss decision affect the result of the match? (which visualizations could be used to present your answer better) And is the impact limited to only specific venues?

select v.Venue_Name, td.Toss_Name as Toss_Decision, count(*) as Total_Matches,
    sum(case when m.Toss_winner = m.Match_winner then 1 else 0 end) as Matches_Won_After_Toss,
    round(sum(case when m.Toss_winner = m.Match_winner then 1 else 0 end) * 100.0 / count(*), 2) as Win_Percentage
from  matches m
join toss_decision td on m.Toss_Decide = td.Toss_Id
join venue v on m.Venue_Id = v.Venue_Id
group by v.Venue_Name, td.Toss_Name
order by v.Venue_Name, Win_Percentage desc;


-- Q.2) 	Suggest some of the players who would be best fit for the team.
        
   -- Top 10 Batsmen with High Average Runs 
select p.Player_Name, round(sum(b.Runs_Scored) * 1.0 / count(distinct m.Match_Id), 2) as Avg_Runs_Per_Match
from ball_by_ball b
join Matches m on b.Match_Id = m.Match_Id
join Player p on b.Striker = p.Player_Id
group by p.Player_Name
having count(distinct m.Match_Id) >= 5  -- filters out players who played very few matches
order by Avg_Runs_Per_Match desc limit 10;

-- Top 10 Bowlers with Total Wickets
select p.Player_Name, count(w.Player_Out) as Total_Wickets
from ball_by_ball b
join Wicket_Taken w on b.Match_Id = w.Match_Id
and b.Over_Id = w.Over_Id
and b.Ball_Id = w.Ball_Id
and b.Innings_No = w.Innings_No
join Player p on b.Bowler = p.Player_Id
group by p.Player_Name
order by Total_Wickets desc limit 10;
    

-- Q.3)	What are some of the parameters that should be focused on while selecting the players?

-- For top batsmen
select p.Player_Name, count(*) as Balls_Faced, SUM(b.Runs_Scored) as Total_Runs, round(sum(b.Runs_Scored) * 1.0 / count(*), 2)*100 AS Strike_Rate
from ball_by_ball b
join matches m on b.Match_Id = m.Match_Id
join season s on m.Season_Id = s.Season_Id
join player p on b.Striker = p.Player_Id
where s.Season_Year >= (select max(Season_Year) - 3 from season)
group by p.Player_Name
having count(*) >= 40 -- minimum balls faced
order by Total_Runs desc limit 10;

-- for top Bowlers
select p.Player_Name, count(*) as Balls_Bowled, count(wt.Player_out) as Wickets, round(count(wt.Player_out) * 1.0 / count(*), 2)*100 AS Balls_Bowled_Per_Wicket
from ball_by_ball b
join matches m on b.Match_Id = m.Match_Id
join season s on m.Season_Id = s.Season_Id
join player p on b.Bowler = p.Player_Id
left join wicket_taken wt on b.Match_Id = wt.Match_Id 
                    and b.Over_Id = wt.Over_Id 
                    and b.Ball_Id = wt.Ball_Id
where s.Season_Year >= (select max(Season_Year) - 3 from season)
group by p.Player_Name
having count(*) >= 30 -- min overs
order by Wickets desc, Balls_Bowled_Per_Wicket desc limit 10;


-- Q.4)Which players offer versatility in their skills and can contribute effectively with both bat and ball? 

select p.Player_Name, coalesce(batting.Total_Runs, 0) as Total_Runs, coalesce(bowling.Total_Wickets, 0) as Total_Wickets
from Player p
left join (select b.Striker as Player_Id, sum(b.Runs_Scored) as Total_Runs
		   from ball_by_ball b
           group by b.Striker) as batting on p.Player_Id = batting.Player_Id
left join (select b.Bowler as Player_Id, count(w.Player_Out) as Total_Wickets
           from ball_by_ball b
           join Wicket_Taken w on b.Match_Id = w.Match_Id 
                       and b.Over_Id = w.Over_Id 
                       and b.Ball_Id = w.Ball_Id 
                       and b.Innings_No = w.Innings_No
           group by b.Bowler) as bowling on p.Player_Id = bowling.Player_Id
where Total_Runs >= 300 and Total_Wickets >= 15
order by Total_Runs desc, Total_Wickets desc;


-- This query identifies players who possess versatility by contributing effectively with both bat and ball. 

-- Q.5)Are there players whose presence positively influences the morale and performance of the team? 


select player_name, count(*) as matches_played, sum(case when team_id = match_winner then 1 else 0 end) as matches_won,
round(sum(case when team_id = match_winner then 1 else 0 end) * 100.0 / count(*), 2) as win_percentage
from (select distinct m.match_id, p.player_name, pb.team_batting as team_id, m.match_winner
	  from ball_by_ball pb
      join matches m on pb.match_id = m.match_id
	  join player p on pb.striker = p.player_id) as player_matches
group by player_name
having matches_played >= 10
order by win_percentage desc limit 10;


-- Q.7)What do you think could be the factors contributing to the high-scoring matches and the impact on viewership and team strategies

-- Identify High-Scoring Matches
select m.Match_Id, t1.Team_Name as Team_1, t2.Team_Name as Team_2, m.Match_Date, m.Win_Margin, m.Match_Winner
from Matches m
join Team t1 on m.Team_1 = t1.Team_Id
join Team t2 on m.Team_2 = t2.Team_Id
where m.Win_Margin is not null
order by m.Win_Margin desc
limit 10;  

-- Identify Teams with High Win Margins
select t.Team_Name, count(m.Match_Id) as Matches_Played, avg(m.Win_Margin) as Average_Win_Margin
from Matches m
join Team t on m.Match_Winner = t.Team_Id
group by t.Team_Name
order by Average_Win_Margin desc;

-- Analyze high-scoring matches, team performances, and the impact of individual awards. 
-- By running these queries, we can gather insights that can inform team strategies and enhance understanding of factors contributing to high-scoring games.


-- Q.8)Analyze the impact of home-ground advantage on team performance and identify strategies to maximize this advantage for RCB. 

-- Analyze Home-Ground Performance
select t.team_name as team, v.venue_name as home_venue, count(*) as matches_played_at_home,
sum(case when m.match_winner = t.team_id then 1 else 0 end) as wins_at_home,
round(sum(case when m.match_winner = t.team_id then 1 else 0 end) * 100.0 / count(*), 2) as win_percentage_at_home
from matches m
join venue v on m.venue_id = v.venue_id                                        
join team t on m.team_1 = t.team_id or m.team_2 = t.team_id
where v.venue_name like '%chinnaswamy%' and t.team_name like '%Bangalore%'
and (m.team_1 = t.team_id or m.team_2 = t.team_id)
group by t.team_name, v.venue_name
order by win_percentage_at_home desc;

-- Monitor and Evaluate Performance
select s.Season_Year, count(m.Match_Id) as Total_Home_Matches,
   sum(case when m.Match_Winner = r.Team_Id then 1 else 0 end) as Wins,
  (sum(case when m.Match_Winner = r.Team_Id then 1 else 0 end) * 100.0 / count(m.Match_Id)) as Win_Percentage
from Matches m
join Team r on (m.Team_1 = r.Team_Id or m.Team_2 = r.Team_Id)
join Season s on m.Season_Id = s.Season_Id
where r.Team_Name = 'Royal Challengers Bangalore'  
and m.Venue_Id = (select Venue_Id from Venue where Venue_Name = 'M Chinnaswamy Stadium') 
group by s.Season_Year
order by s.Season_Year;

-- By analyzing home-ground performance and implementing targeted strategies, RCB can maximize their home advantage. 
-- This includes player selection, preparation, fan engagement, tactical adjustments, and ongoing performance monitoring. 
-- These strategies can help RCB improve their chances of winning at home and enhance overall team performance. 


-- Q.9)Come up with a visual and analytical analysis of the RCB's past season's performance and potential reasons for them not winning a trophy.


-- Win percentage in each season
select s.season_year, count(m.match_id) as matches_played, sum(case when m.match_winner = t.team_id then 1 else 0 end) as matches_won,
round(sum(case when m.match_winner = t.team_id then 1 else 0 end) * 100.0 / count(m.match_id), 2) as win_percentage
from matches m
join season s on m.season_id = s.season_id
join team t on t.team_name = 'Royal Challengers Bangalore'
where m.team_1 = t.team_id or m.team_2 = t.team_id
group by s.season_year
order by s.season_year;

-- Batting consistency (average runs per match)
select p.player_name, round(sum(b.runs_scored) * 1.0 / count(distinct m.match_id), 2) as avg_runs
from ball_by_ball b
join matches m on b.match_id = m.match_id
join player p on b.striker = p.player_id
where b.team_batting = 2
group by p.player_name                                                 
having count(distinct m.match_id) >= 5
order by avg_runs desc;

-- Bowling performance (economy rate)
select p.player_name, round(sum(b.runs_scored) * 6.0 / count(*), 2) as economy_rate
from ball_by_ball b
join player p on b.bowler = p.player_id                                   
where b.bowler in (select distinct b1.bowler
                   from ball_by_ball b1
                   where b1.team_bowling = 2)
group by p.player_name
having count(*) >= 30
order by economy_rate asc;

-- //Overall Performance: RCB's low win percentage reflects inconsistency in converting matches into victories, impacting their trophy chances.
-- Key Player Contributions: Reliance on a few standout players without sufficient support from the team may have hindered overall success.


-- Q.11)In the "Match" table, some entries in the "Opponent_Team" column are incorrectly spelled as "Delhi_Capitals" instead of "Delhi_Daredevils". Write an SQL query to replace all occurrences of "Delhi_Capitals" with "Delhi_Daredevils".

select * from Team where Team_Id = 6;
update Team set Team_Name = "Delhi Daredevils" where Team_Id = 6;


-- Note- already have team name as “Delhi-Daredevils” in a team column.
-- This query updates the "Opponent_Team" column in the "Match" table, replacing all occurrences of "Delhi_Capitals" with "Delhi_Daredevils".
-- also already have a team name "Delhi-Daredevils" in Team table.