-- Xem dữ liệu

select * 
from Covid_data
order by Location, date

-- Số ca nhiễm hiện tại ở các nước và thông tin nhân khẩu hiện tại ở các nước
IF OBJECT_ID('dbo.current_info', 'V') IS NOT NULL
    DROP VIEW dbo.current_info
go
Create view current_info as 
select sub.location,sub.continent,sub.current_cases,sub.current_deaths,c.population,c.gdp_per_capita,c.life_expectancy,c.median_age
from
	(select c1.location, c1.continent, max(c1.total_cases) as current_cases,max(c1.total_deaths) as current_deaths
	from Covid_data as c1
	where c1.continent is not null
	group by c1.location,c1.continent) as sub
left join (
	select distinct location, population, gdp_per_capita, life_expectancy,median_age
	from Covid_data) as c
on sub.location = c.location


-- Số ca nhiễm và GDP các nước
select location, continent,avg(gdp_per_capita) as gdp_per_capita,max(total_cases) as current_cases
from Covid_data
where continent is not null
group by location,continent
order by current_cases desc

select distinct(continent)
from covid_data

-- Countries with most cases in every continents
select distinct location,total_cases,continent
from covid_data
where total_cases in
	(select max(total_cases)
	from covid_data
	where continent is not null
	group by continent)

-- Countries with the most deaths in every continents
select distinct location, total_deaths, c.continent
from Covid_data as c
inner join (
	select max(total_deaths) as max_deaths,continent
	from covid_data
	group by continent) as sub
on sub.continent = c.continent and c.total_deaths =  sub.max_deaths
where c.continent is not null
------------------------------------------------------------------------

-- ti le nhiem benh va tu vong o cac nuoc lon thoi diem hien tai
select location,continent,population,(total_cases/population)*100 as Infected_percent,(total_deaths/population)*100 as Dead_percent
from covid_data
where continent is not null and date ='2021-12-13'
order by Dead_percent desc


-- Tinh ti le nguoi duoc tiem 2 mui tren ca nuoc
select ok.location,ok.vaccine_percent, co.continent
from
	(select vaccine.location,(max(people_fully_vaccinated)/avg(population))*100 as vaccine_percent
	from Vaccine
	left join 
			(select distinct(location),continent
			from Covid_data) as sub
	on vaccine.location = sub.location
	where sub.continent is not null
	group by vaccine.location) as ok
inner join 
	(select distinct(location), continent
	from covid_data) as co
on ok.location =co.location
where continent = 'Asia'
order by vaccine_percent desc

-- Tinh ti le nguoi duoc tiem vaccine tren ca nuoc

WITH data (location,continent,fully_vaccine_percent, vaccine_percent) as 
(select ok.location, co.continent,ok.fully_vaccine_percent,ok.vaccine_percent
from
	(select vaccine.location,(max(people_vaccinated)/avg(population))*100 as vaccine_percent,(max(people_fully_vaccinated)/avg(population))*100 as fully_vaccine_percent
	from Vaccine
	left join 
			(select distinct(location),continent
			from Covid_data) as sub
	on vaccine.location = sub.location
	where sub.continent is not null
	group by vaccine.location) as ok
inner join 
	(select distinct(location), continent
	from covid_data) as co
on ok.location =co.location)


select * from data
order by location

-- tao bang tam
drop table if exists Current_vaccine_percent
create table Current_vaccine_percent
(
location nvarchar(255),
continent nvarchar(255),
fully_vaccine_percent float,
vaccine_percent float)
insert into Current_vaccine_percent

select ok.location, co.continent,ok.fully_vaccine_percent,ok.vaccine_percent
from
	(select vaccine.location,(max(people_vaccinated)/avg(population))*100 as vaccine_percent,(max(people_fully_vaccinated)/avg(population))*100 as fully_vaccine_percent
	from Vaccine
	left join 
			(select distinct(location),continent
			from Covid_data) as sub
	on vaccine.location = sub.location
	where sub.continent is not null
	group by vaccine.location) as ok
inner join 
	(select distinct(location), continent
	from covid_data) as co
on ok.location =co.location
order by location
--
IF OBJECT_ID('dbo.test', 'V') IS NOT NULL
    DROP VIEW dbo.test
go
create view test as(
select ok.location, co.continent,onemui,twomui,danso
from
	(select vaccine.location,max(people_vaccinated) as onemui,avg(population) as danso,max(people_fully_vaccinated) as twomui
	from Vaccine
	left join 
			(select distinct(location),continent
			from Covid_data) as sub
	on vaccine.location = sub.location
	where sub.continent is not null
	group by vaccine.location) as ok
inner join 
	(select distinct(location), continent
	from covid_data) as co
on ok.location =co.location)
--
select * from Current_vaccine_percent
order by location
-----------------------------------------

-- Ti le tiem phong va nhiem benh theo tung ngay
drop table if exists data
create table DATA 
( location nvarchar(255)
,date date
,total_infecteds numeric
,total_deaths numeric
,total_vaccines numeric
,total_people_vaccinated numeric
,total_people_fully_vaccinated numeric)

insert into DATA
select
	vaccine.location,vaccine.date,
	sum(new_cases) over(partition by covid_data.location order by covid_data.date rows between unbounded preceding and current row) as total_infecteds,
	sum(new_deaths) over(partition by covid_data.location order by covid_data.date rows between unbounded preceding and current row) as total_deaths,
	sum(new_vaccinations_smoothed) over(partition by vaccine.location order by vaccine.date rows between unbounded preceding and current row) as total_vaccines,
	max(people_vaccinated) over(partition by vaccine.location order by vaccine.date rows between unbounded preceding and current row) as total_people_vaccinated,
	max(people_fully_vaccinated) over(partition by vaccine.location order by vaccine.date rows between unbounded preceding and current row) as total_people_fully_vaccinated
from Vaccine
inner join Covid_data
on vaccine.location = Covid_data.location and vaccine.date = Covid_data.date
where vaccine.continent is not null
select * from DATA order by location,date

--Tao 1 bang de visual
drop table if exists overall_covid19_table
select c.location, c.date,
	c.total_cases,
	(total_infecteds/population)*100 as infected_percent,
	(d.total_deaths/total_infecteds)*100 as rate_of_deaths_among_infected_people,
	(d.total_people_vaccinated/population)*100 as vaccinated_rate,
	(d.total_people_fully_vaccinated/population)*100 as fully_vaccinated_rate
into overall_covid19_table
from DATA as d
inner join Covid_data as c
on d.location = c.location and d.date = c.date
order by location,date

-- Tao view de visual


drop view if exists Overall_covid19
go
create view Overall_covid19 as
select c.location, c.date,
	c.total_cases,
	(total_infecteds/population)*100 as infected_percent,
	(d.total_deaths/total_infecteds)*100 as rate_of_deaths_among_infected_people,
	(d.total_people_vaccinated/population)*100 as vaccinated_rate,
	(d.total_people_fully_vaccinated/population)*100 as fully_vaccinated_rate
from DATA as d
inner join Covid_data as c
on d.location = c.location and d.date = c.date


