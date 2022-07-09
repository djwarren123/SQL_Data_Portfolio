
----------------------------------------------------------------
----------------------------------------------------------------
---find the most popular genre
----------------------------------------------------------------
----------------------------------------------------------------


select 
	sum(total) as total_sales 
	, g."name" 
from 
	invoice i 
	inner join invoiceline il 
		on i.invoiceid = il.invoiceid 
	inner join track t 
		on t.trackid = il.trackid 
	inner join genre g 
		on t.genreid = g.genreid 
group by g."name"
order by tot_sal desc;


----------------------------------------------------------------
----------------------------------------------------------------
--- Count how many albums each artist has created
----------------------------------------------------------------
----------------------------------------------------------------


SELECT 
      a.Name
    , COUNT(DISTINCT t.AlbumId) AS albums_per_artist
FROM 
	Track t
    INNER JOIN album  al
	    ON t.AlbumId = al.AlbumId
	INNER join Artist a
		ON al.ArtistId = a.ArtistId       
GROUP BY a.Name
ORDER BY albums_per_artist desc;


----------------------------------------------------------------
----------------------------------------------------------------
--- Top 3 customers with the highest sales in each country
----------------------------------------------------------------
----------------------------------------------------------------


---first make a query to get the list of customers with the highest sales total


select 
	*
	,row_number () over (partition by billingcountry order by max(total) desc) as rn
from 
	invoice i
group by 
	 i.billingcountry 
	, i.invoiceid;


----- now make it into a subquery in the from clause and filter down to the top 2


select *
from 
	( select 
		*
		, i.customerid
		,row_number () over (partition by billingcountry order by max(total) desc) as rn
from 
	invoice i
group by 
	i.billingcountry 
	, i.customerid 
	, i.invoiceid  ) as x
where x.rn <= 3;


---- now lets filter down to get the name of customers name and get rid of duplicates


select *
from 
	( select 
		 distinct c.customerid
		, concat(c.firstname, ' ' , c.lastname) as full_name
		, i.total 
		,i.billingcountry as country
		, row_number () over (partition by billingcountry order by max(total) desc) as rn
		from invoice i
			inner join customer c 
				ON i.customerid = c.customerid 
		group by 
			c.customerid 
			, i.invoiceid ) as x
where x.rn <= 3
order by country, x.rn  asc;


----------------------------------------------------------------
----------------------------------------------------------------
---- Find the genre with the most tracks created
----------------------------------------------------------------
----------------------------------------------------------------


SELECT 
    track.GenreId
    , genre.name
    , COUNT(*) as genre_count
FROM 
	PlaylistTrack
    INNER JOIN Track 
        ON playlisttrack.TrackId = track.TrackId
    inner join genre
    	on genre.genreid = track.genreid 
GROUP BY track.GenreId, genre.name
ORDER BY genre_count DESC;


----------------------------------------------------------------
----------------------------------------------------------------
---- Finding the amount of albums and songs made per artist
----------------------------------------------------------------
----------------------------------------------------------------


SELECT  
    artist.Name
    , COUNT(*) AS songs_per_artist
    , COUNT(DISTINCT track.AlbumId) AS albums_per_artist
    , CAST(COUNT(*) AS NUMERIC) / COUNT(DISTINCT track.AlbumId) AS songs_albums_ratio
FROM 
	track
    INNER JOIN Album
		ON track.AlbumId = album.AlbumId
	INNER JOIN Artist
		ON album.ArtistId = artist.ArtistId
GROUP BY artist.Name
ORDER BY albums_per_artist DESC;


----------------------------------------------------------------
----------------------------------------------------------------
---- Count the tracks by minute intervals to find popularity
----------------------------------------------------------------
----------------------------------------------------------------

---  change data to seconds
	
	
select cast (milliseconds * .001 as int) as seconds 
from track t ;


---  make it into cte then case


with track_time as (
	select count(il.invoicelineid) 
		   ,cast (milliseconds * .001 as int) as seconds 
	from track t
		inner join invoiceline il on t.trackid = il.trackid
		group by t.milliseconds)
select  
	  count(case when seconds <= '60' then 1 end) as under_1min
	, count( case when seconds >= '61' and seconds <= '120' then 1 end) as one_two_mins
	, count( case when seconds >= '121' and seconds <= '180' then 1 end) as two_three_mins
	, count( case when seconds >= '181' and seconds <= '240' then 1 end) as three_four_mins
	, count( case when seconds >= '241' and seconds <= '300' then 1 end) as four_five_mins
	, count( case when seconds >= '301' and seconds <= '360' then 1 end) as five_six_mins
	, count( case when seconds >= '361' then 1 end) as sixmins_or_longer
from 
	track_time t;


----------------------------------------------------------------
----------------------------------------------------------------
--- Metallica gave a %10 discount on all there albums
--- calulate what there actual sales should be
----------------------------------------------------------------
----------------------------------------------------------------
	
---first find all the sales for metallica

	
select
	a."name" 
	, sum(i.total)  as total_sales
from 
	artist a 
		inner join album al on a.artistid = al.artistid 
		inner join track t on al.albumid = t.albumid 
		inner join invoiceline il on il.trackid = t.trackid 
		inner join invoice i on i.invoiceid = il.invoicelineid 
where a."name" = 'Metallica'
group by a."name"; 

	
--- 148.85 is the sales total


with metallica_sales as (
select
	a."name" 
	, sum(i.total)  as total_sales
from 
	artist a 
		inner join album al on a.artistid = al.artistid 
		inner join track t on al.albumid = t.albumid 
		inner join invoiceline il on il.trackid = t.trackid 
		inner join invoice i on i.invoiceid = il.invoicelineid 
where a."name" = 'Metallica'
group by a."name" )
	select 
			case 
			when ms."name" = 'Metallica' then total_sales  - (total_sales  * .10)
		end as true_sales
		from 
		metallica_sales ms;

	
	---- new sales total 133.965

----------------------------------------------------------------
----------------------------------------------------------------
---Most popular words from track titles
----------------------------------------------------------------
----------------------------------------------------------------


select 
	word
	,count(*) 
from 
	(
    select split_part(name, ' ', 1) as word
    from track) as words
where word is not null
	and word NOT IN ('', 'and', 'for', 'of', 'on')
group by word
order by count desc;
	



----------------------------------------------------------------
----------------------------------------------------------------
---- Average minutes per track for each genre
----------------------------------------------------------------
----------------------------------------------------------------

select
	g.name
	, cast (avg(t.milliseconds) / 60000 as int) as avg_minutes
from
	track t 
	inner join genre g on t.genreid = g.genreid 
group by g."name" , g.genreid 
order by avg_minutes desc;


----------------------------------------------------------------
----------------------------------------------------------------
--- Count album titles with the word rock in them
----------------------------------------------------------------
----------------------------------------------------------------


select
		 count ( case when title like '%%Rock%%' then 'Rock_title' end ) as rockout 
		,count ( case when title not like '%Rock%%' then 'No_rock' end ) as norockout
from album; 


----------------------------------------------------------------
----------------------------------------------------------------
--- Albums with best sales in each genre
----------------------------------------------------------------
----------------------------------------------------------------


SELECT DISTINCT 
       g.Name Genre
       ,FIRST_VALUE(a.Title) OVER (PARTITION BY g.GenreId ORDER BY COUNT(*) DESC) Album 
       ,FIRST_VALUE(r.Name) OVER (PARTITION BY g.GenreId ORDER BY COUNT(*) DESC) Artist
       ,MAX(COUNT(*)) OVER (PARTITION BY g.GenreId) Sales
FROM genre g
	INNER JOIN track t ON t.GenreId = g.GenreId
	INNER JOIN album a ON a.AlbumId = t.AlbumId
	INNER JOIN artist r ON r.ArtistId = a.ArtistId
	INNER JOIN invoice i ON t.TrackId = t.trackid 
GROUP BY 
	g.GenreId
	, a.AlbumId
	, r."name" ;
	

--top 5 customers who spent the most on tracks
----------------------------------------------


select 
	sum(i.total) as total_spent ,
	concat(c.firstname, ' ' , c.lastname) as full_name
from 
	customer c 
	inner join invoice i on c.customerid = i.customerid 
group by 
	i.total 
	, c.firstname 
	,c.lastname 
order by i.total desc
limit 5;



--customers with higher than avg sales
----------------------------------------------


with average_total (avg_tot) as 
	(select avg(total) from invoice i)
select i.customerid
from 
	invoice i
	, average_total a
group by i.invoiceid, a.avg_tot
	having i.total > a.avg_tot 
order by i.total desc;

	
----customers with lower than avg sales

with average_total (avg_tot) as 
	(select avg(total) from invoice i)
select i.customerid
from 
	invoice i
	, average_total a
group by i.invoiceid, a.avg_tot
	having i.total < a.avg_tot 
order by i.total desc;















