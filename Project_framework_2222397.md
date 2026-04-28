**PROJECT FRAMEWORK & IMPLEMENTATION PLAN**

A Comparative Analysis of the Carbon Footprint of

**REST vs. GraphQL APIs in Mobile Environments**

Green Software Engineering \| Software Engineering Course

  -----------------------------------------------------------------------
  **Name:**                         Muntasir Rahman Rafin
  --------------------------------- -------------------------------------
  **Student ID:**                   2222397

  **Course:**                       CSE451

  **Section:**                      2

  **Research Type:**                Empirical Comparative Study

  **Domain:**                       Green Software Engineering

  **Tech Stack:**                   Flutter + Flask + SQLite

  **Timeline:**                     16 Feb 2026 -- April 2026
  -----------------------------------------------------------------------

# **1. Executive Summary**

This is the project framework for a research study comparing how much
energy REST and GraphQL APIs consume in a mobile app environment. It
sits under Green Software Engineering, which is basically the area of
computer science focused on making software use less energy and produce
less carbon.

The core question is simple: if you build the same Flutter app twice,
once using REST and once using GraphQL, which one drains less battery
when fetching data? To answer this properly, we will run each app
through thousands of controlled test cycles and measure the energy in
Joules using a tool called PowerAPI.

The app we are building is a mini movie and TV database, like a
lightweight IMDB. It is a good choice because movie data has naturally
complex nested structure, which is exactly where REST and GraphQL behave
differently from each other.

On top of the measurement study, we will build a small Adaptive API
Gateway prototype. This is a tool that watches which API is more
efficient for each type of request, remembers the result, and
automatically routes future requests to the better option. This makes
the project more interesting than just reporting numbers.

The project has to be done by end of April 2026. Starting today, 22nd
February, that gives us 10 weeks. The plan below fits everything into
that window with a small buffer at the end.

# **2. Research Framework**

## **2.1 Research Question**

Main question: What is the difference in energy consumption, measured in
Joules, between REST and GraphQL APIs when a Flutter mobile app fetches
data 1,000 times in a row?

Two follow-up questions that support the main one:

-   Does the complexity of the data being fetched change which API is
    > more efficient?

-   Can a tool that learns from past measurements automatically route
    > requests to the cheaper API, and how much energy does that
    > actually save?

## **2.2 Hypotheses**

H1 (Null Hypothesis): There is no real energy difference between REST
and GraphQL under the same conditions.

H2 (Alternative Hypothesis): REST uses more energy on large complex
payloads because it sends data the app did not ask for. GraphQL uses
more energy on small simple requests because it parses every query
before responding. Neither one always wins, it depends on the situation.
If H2 is correct, that is actually the best possible outcome for this
project because it proves the Adaptive Gateway is worth building.

## **2.3 Variables**

  ------------------------------------------------------------------------
  **Variable Type**   **Variable**             **Details**
  ------------------- ------------------------ ---------------------------
  **Independent**     API Protocol             REST vs. GraphQL

  **Dependent**       Energy Consumption       Measured in Joules (J)

  **Dependent**       Response Time            Measured in milliseconds
                                               (ms)

  **Control**         Backend                  Same Flask server and
                                               SQLite DB for both APIs

  **Control**         Device and OS            Same Android phone, fixed
                                               OS version throughout

  **Control**         Network                  WiFi only, same router, no
                                               other devices on network
                                               during tests

  **Confound          Background Processes     Device in Do Not Disturb,
  (managed)**                                  no other apps open during
                                               tests
  ------------------------------------------------------------------------

# **3. What We Are Building**

## **3.1 The App: Mini Movie and TV Database**

Both Flutter apps will look and work exactly the same from a user\'s
perspective. You open the app, see a list of movies, tap one, see its
details, and can browse the cast. The screens, layout, and navigation
are copied from a shared template. The only thing that differs between
the two apps is how they get their data.

We are testing three types of data requests, which we call payload
sizes:

-   Small: just the movie title, release year, and rating. Around 5 data
    > fields. This is the kind of request you\'d make to show a summary
    > card in a list.

-   Medium: movie details plus the director name and genre tags. Around
    > 20 fields. A typical detail screen.

-   Large: the full movie record, every cast member with their bio, and
    > all user reviews. 50 or more nested fields. This is where REST and
    > GraphQL are most likely to behave differently.

## **3.2 Flask Backend**

One Flask app running locally on a laptop handles everything. It reads
from a single SQLite database and exposes both:

-   REST endpoints: /api/movies for the list, /api/movies/\<id\> for
    > details, /api/movies/\<id\>/cast for cast info

-   GraphQL endpoint: a single /graphql route using the Strawberry
    > library, covering all the same data

Running locally means no internet latency gets into the energy
measurements. The SQLite database is pre-seeded with around 500 movies
and 2,000 actors, so every test run pulls exactly the same records.

## **3.3 The Two Flutter Apps**

  -----------------------------------------------------------------------
  **REST Flutter App**                **GraphQL Flutter App**
  ----------------------------------- -----------------------------------
  Uses the http or dio package        Uses the graphql_flutter package

  Hits different endpoints for        Sends one query to /graphql
  different data types                specifying exactly which fields it
                                      wants

  Might send more data than needed on Adds query parsing overhead to
  complex screens                     every single request

  Identical UI, screens, and          Identical UI, screens, and
  navigation to the GraphQL app       navigation to the REST app
  -----------------------------------------------------------------------

## **3.4 The Adaptive API Gateway**

After the measurement phase is done, we build a lightweight Python
middleware that sits between the Flutter app and the two backends. It
does three things:

-   Learns: For the first 10 requests of each payload type (small,
    > medium, large), it sends the request to both APIs, measures energy
    > and speed, and records which one came out cheaper.

-   Remembers: It stores the results in a small SQLite table. Something
    > like: large nested requests, GraphQL was 18 percent cheaper.
    > Medium requests, REST was faster.

-   Routes: From that point on, every incoming request of a known type
    > goes straight to the winner. No more testing both sides. If a new
    > request type shows up that it has not seen before, it goes back to
    > the learning step.

This is a prototype, not a production system. The classification is
simple, bucket by small, medium, or large payload, rather than exact
query matching. The paper will discuss what a more advanced version with
machine learning could look like as future work.

# **4. 10-Week Implementation Plan (22 Feb -- End of April 2026)**

## **Overview**

  -------------------------------------------------------------------------
  **Dates**   **Phase**    **What Gets Done**           **End Deliverable**
  ----------- ------------ ---------------------------- -------------------
  22 Feb -- 7 **Phase 1**  Flask backend, SQLite        Working local
  Mar                      database, seed data, both    server
                           APIs working and tested      

  8 Mar -- 21 **Phase 2**  Both Flutter apps built from Two working APKs
  Mar                      shared template, data        
                           fetching integrated,         
                           equivalence verified         

  22 Mar -- 4 **Phase 3**  All 180 test runs completed, Raw dataset
  Apr                      energy and timing data       (180,000 cycles)
                           logged to CSV                

  5 Apr -- 11 **Phase 4**  Statistical analysis,        Results + working
  Apr                      charts, Green Ranking table, gateway
                           Adaptive Gateway prototype   
                           built and validated          

  12 Apr --   **Phase 5**  Full paper written,          Submitted IEEE
  30 Apr                   supervisor review,           paper
                           revisions, final submission  
  -------------------------------------------------------------------------

## **Phase 1: Backend and Database (22 Feb -- 7 Mar, 2 weeks)**

This is the foundation. If the backend is shaky, everything else falls
apart. Two weeks feels tight but Flask is fast to set up and SQLite
needs no server configuration.

**Week 1 (22 Feb -- 28 Feb)**

-   Set up Flask project with a virtual environment, install Flask,
    > Strawberry, and SQLAlchemy

-   Design the SQLite schema: Movies, Actors, Genres, Reviews, and a
    > Cast join table

-   Write the database seed script, aim for around 500 movies and 2,000
    > actors with realistic data

-   Build and test the three REST endpoints: movie list, movie detail,
    > and cast

**Week 2 (1 Mar -- 7 Mar)**

-   Build the GraphQL schema and resolvers in Strawberry covering the
    > same data as REST

-   Write tests that call both APIs with the same query and confirm they
    > return identical JSON

-   These equivalence tests are not optional, they are the scientific
    > proof that the experiment is controlled

-   Deliverable by 7 Mar: Flask server running locally with both APIs
    > fully tested and documented

## **Phase 2: Flutter Apps (8 Mar -- 21 Mar, 2 weeks)**

The Flutter work is the most unpredictable part of the whole project.
Two weeks is realistic but only if you start from a shared UI template
rather than building each app from scratch independently.

**Week 3 (8 Mar -- 14 Mar)**

-   Create the shared Flutter template: movie list screen, movie detail
    > screen, cast screen

-   Make sure the UI is complete and polished before duplicating it,
    > fixing UI bugs in two separate projects later is painful

-   Fork the template into two projects: one named rest_app and one
    > named graphql_app

-   Integrate the http or dio package in rest_app and wire up the three
    > REST endpoints

**Week 4 (15 Mar -- 21 Mar)**

-   Integrate graphql_flutter in graphql_app and write the three GraphQL
    > queries

-   Run side-by-side tests: same search, same movie, confirm both apps
    > show the same data on every screen

-   Set up PowerAPI on the host laptop, verify RAPL is accessible, run 5
    > pilot energy measurement tests

-   Deliverable by 21 Mar: Two working APKs that are functionally
    > identical, measurement tooling confirmed working

## **Phase 3: Benchmarking and Measurement (22 Mar -- 4 Apr, 2 weeks)**

This is the most time-consuming phase but also the most mechanical. The
Python test harness does most of the work, you just need to make sure it
runs cleanly and the device stays in a controlled state.

**Test Matrix (180 total runs)**

  -----------------------------------------------------------------------
  **API**           **Payload**       **Data Fetched**  **Runs**
  ----------------- ----------------- ----------------- -----------------
  REST              Small             Title + year +    30
                                      rating            

  REST              Medium            Details +         30
                                      director + genres 

  REST              Large             Full movie +      30
                                      cast + reviews    

  GraphQL           Small             Title + year +    30
                                      rating            

  GraphQL           Medium            Details +         30
                                      director + genres 

  GraphQL           Large             Full movie +      30
                                      cast + reviews    
  -----------------------------------------------------------------------

-   Each run = 1,000 fetch cycles. 30 runs per combination x 6
    > combinations = 180 runs total = 180,000 cycles

-   Every run logs: Joules consumed, response time in ms, payload size
    > in KB, API used, payload type, timestamp

-   Wait 30 seconds between runs, device in Do Not Disturb, no other
    > apps running

-   Deliverable by 4 Apr: Complete CSV dataset, no missing runs

## **Phase 4: Analysis and Adaptive Gateway (5 Apr -- 11 Apr, 1 week)**

One week sounds tight but the analysis is straightforward with pandas
and scipy, and the gateway prototype is simple by design. Do the
analysis first, then build the gateway.

**Analysis (5 Apr -- 7 Apr)**

-   Calculate mean, median, and standard deviation of Joules and
    > response time per group

-   Run Mann-Whitney U tests to check statistical significance, target p
    > less than 0.05

-   Generate bar charts and box plots comparing REST vs. GraphQL across
    > the three payload sizes

-   Build the Green Ranking table: which API wins for small, medium, and
    > large payloads, with the actual Joule difference written out

**Adaptive Gateway Prototype (8 Apr -- 11 Apr)**

-   Build as a small Flask middleware that intercepts requests from the
    > Flutter app

-   Learning phase: route first 10 requests of each payload bucket to
    > both APIs, measure, record winner in SQLite

-   Routing phase: all subsequent requests of a known type go straight
    > to the winner

-   Run a quick validation: 1,000 mixed requests through the gateway vs.
    > always-REST and always-GraphQL, compare total energy

-   Deliverable by 11 Apr: Analysis charts ready for the paper, gateway
    > prototype working with a one-page test report

## **Phase 5: Paper Writing (12 Apr -- 30 Apr, \~2.5 weeks)**

Do not leave this until the last few days. Writing a proper IEEE paper
takes longer than most students expect. The plan below spreads it
realistically.

**12 Apr -- 18 Apr**

-   Write the Introduction (why this matters, what the gap in literature
    > is)

-   Write the Related Work section using the 15 identified papers, group
    > them by theme

-   Write the Methodology section, this is basically a more formal
    > version of sections 3 and 4 of this document

**19 Apr -- 24 Apr**

-   Write the Results section, paste in the charts and tables, explain
    > what the numbers mean

-   Write the Discussion section, compare results to existing
    > literature, explain surprises

-   Write the Adaptive Gateway section, describe the prototype and
    > report its measured energy savings

-   Send the full draft to your supervisor for feedback

**25 Apr -- 30 Apr**

-   Revise based on supervisor feedback

-   Write the Abstract and Conclusion last, they are easier once the
    > body is done

-   Format everything to the IEEE conference template in LaTeX

-   Final proofread and submit

# **5. Technical Stack**

  ------------------------------------------------------------------------
  **Layer**         **Technology**          **Why This Choice**
  ----------------- ----------------------- ------------------------------
  **Backend**       Python + Flask          Lightweight, quick to set up,
                                            handles both REST and GraphQL
                                            easily

  **GraphQL         Strawberry (Python)     Clean Python-native GraphQL,
  Library**                                 works well with Flask

  **Database**      SQLite (seeded)         No server needed, easy to seed
                                            and reset, perfect for
                                            controlled experiments

  **ORM**           SQLAlchemy              Standard way to connect Flask
                                            to SQLite

  **Mobile App      Flutter + http / dio    REST client, identical UI to
  (REST)**                                  the GraphQL app

  **Mobile App      Flutter +               GraphQL client, identical UI
  (GraphQL)**       graphql_flutter         to the REST app

  **Energy          PowerAPI v0.7+          Reads CPU and RAM energy via
  Measurement**                             Intel RAPL, outputs Joules

  **Test            Python (custom script)  Automates 1,000-cycle runs and
  Automation**                              saves results to CSV

  **Adaptive        Python + Flask          Routes requests to the more
  Gateway**         middleware              efficient API based on past
                                            measurements

  **Data Analysis** Python: pandas, scipy,  Stats, significance tests, and
                    seaborn                 chart generation

  **Version         GitHub                  All code, data, and docs in
  Control**                                 one repo

  **Paper**         LaTeX (IEEE template)   Standard conference paper
                                            format
  ------------------------------------------------------------------------

# **6. Risks and How to Handle Them**

  ------------------------------------------------------------------------------------
  **Risk**             **Likelihood**   **Impact**   **Plan**
  -------------------- ---------------- ------------ ---------------------------------
  Flutter app          Medium           High         Build the UI template first in
  development runs                                   week 3 before splitting into two
  over time                                          apps. This is the single biggest
                                                     time saver in Phase 2.

  PowerAPI cannot      High             Medium       Measure on the host laptop side
  directly measure                                   using Intel RAPL instead. This is
  phone battery draw                                 actually acceptable for the paper
                                                     as long as you describe it
                                                     clearly in the methodology.

  Background processes Medium           High         Do Not Disturb mode, close all
  on the phone skew                                  apps, subtract idle baseline, 30
  energy readings                                    runs per group gives enough data
                                                     to average out noise.

  The two apps turn    Medium           High         Write equivalence tests in Phase
  out to not be truly                                1 that verify both APIs return
  equivalent                                         identical JSON for identical
                                                     queries. Do not skip this step.

  Results show no      Low              Low          A null result is still
  significant energy                                 publishable and scientifically
  difference at all                                  valid. The Adaptive Gateway still
                                                     gives the paper a second
                                                     contribution regardless.

  Paper writing runs   Medium           High         Start writing the Introduction
  out of time in the                                 and Related Work sections in
  last week                                          parallel with Phase 4. Do not
                                                     wait until everything is done.
  ------------------------------------------------------------------------------------

# **7. What Gets Submitted at the End**

## **7.1 Code (on GitHub)**

-   Flask backend with REST and GraphQL endpoints

-   Flutter REST app, source code and APK

-   Flutter GraphQL app, source code and APK

-   Python test harness for automated energy measurement

-   Adaptive API Gateway prototype

## **7.2 Data and Results**

-   Raw CSV dataset from all 180 test runs (180,000 fetch cycles)

-   Statistical summary tables with mean, median, standard deviation,
    > and confidence intervals

-   Charts comparing REST vs. GraphQL energy and response time across
    > payload sizes

-   Green Ranking table showing which API to use per payload type with
    > actual Joule differences

-   Gateway validation report showing energy saved vs. always using one
    > API

## **7.3 Academic Submission**

-   Research paper in IEEE conference format, 6 to 8 pages

-   This project framework document

-   Slides for faculty presentation if required

# **8. How We Know It Is Done**

The project is complete and successful when all five of these are true:

1.  Both Flutter apps pass equivalence tests confirming they show
    > identical data for identical queries.

2.  At least 150 of the 180 planned test runs complete without errors or
    > data corruption.

3.  At least one statistically significant energy difference (p less
    > than 0.05) is found between REST and GraphQL in any payload
    > category.

4.  The Adaptive Gateway prototype shows a measurable energy saving
    > compared to always routing to one API.

5.  The IEEE-formatted paper is submitted by end of April 2026.

# **9. Key References**

These are the core papers this project builds on. Full IEEE-formatted
bibliography will be in the final paper.

-   Niswar et al. (2024). Performance Evaluation of Microservices
    > Communication with REST, GraphQL, and gRPC. International Journal
    > of Electronics and Telecommunications, Vol. 70(2).

-   Fieni et al. (2024). PowerAPI: A Python Framework for Building
    > Software-Defined Power Meters. Journal of Open Source Software.

-   Rua and Saraiva (2023). A Large-Scale Empirical Study on Mobile
    > Performance: Energy, Run-Time and Memory. Empirical Software
    > Engineering, Springer, Q1.

-   Elghazal, Aneiba and Shahra (2025). Performance Evaluation of REST
    > and GraphQL API Models in Microservices Software Development
    > Domain. WEBIST 2025.

-   Seabra and Nazario (2022). REST or GraphQL? A Performance
    > Comparative Study. ACM / Semantic Scholar.

-   Guldner et al. (2024). Green Software Measurement Model. Future
    > Generation Computer Systems, Elsevier, Q1.
