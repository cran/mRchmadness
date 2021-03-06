#' Scrape the game-by-game results of the NCAA MBB seaon
#'
#' @param year a numeric value of the year, between 2002 and 2017 inclusive
#' @param sex either 'mens' or 'womens'
#' @return data.frame with game-by-game results
#' @export
#' @author eshayer
scrape.game.results = function(year, sex = c('mens', 'womens')) {
  sex = match.arg(sex)
  `%>%` = dplyr::`%>%`

  if (missing(year))
    stop('scrape.game.results: A year must be provided')
  if (!(class(year) %in% c('integer', 'numeric')))
    stop('scrape.game.results: The year must be numeric')
  if (year < 2002 | year > 2017)
    stop('The available seasons are 2002 to 2017')

  teams = scrape.teams(sex)
  
  results = data.frame(game.id = character(0),
                       primary.id = character(0),
                       primary.score = character(0),
                       other.id = character(0),
                       other.score = character(0),
                       home = character(0),
                       location = character(0),
                       ot = character(0))
  
  for (team.id in teams$id) {
    results = rbind(results, scrape.team.game.results(year, team.id, sex))
  }

  results = results %>%
    dplyr::mutate(home = ifelse(location %in% c('H', 'A'),
                                ifelse(location == 'H', TRUE, FALSE),
                                ifelse(is.na(other.id) |
                                         primary.id < other.id,
                                       TRUE, FALSE)))
  
  results = results %>%
    dplyr::transmute(game.id = game.id,
                     home.id = ifelse(home, primary.id, other.id),
                     away.id = ifelse(home, other.id, primary.id),
                     home.score = ifelse(home, primary.score, other.score),
                     away.score = ifelse(home, other.score, primary.score),
                     neutral = ifelse(location == 'N', 1, 0),
                     ot = ot)
  
  results$home.id = ifelse(is.na(results$home.id), 'NA', results$home.id)
  results$away.id = ifelse(is.na(results$away.id), 'NA', results$away.id)
  
  results = results %>%
    dplyr::filter(home.id %in% results$away.id & away.id %in% results$home.id)
  
  unique(results)
}

#' Scrape the team names and ids from the ESPN NCAA MBB index
#'
#' @param sex either 'mens' or 'womens'
#' @return data.frame of team names and ids
#' @author eshayer
scrape.teams = function(sex) {
  `%>%` = dplyr::`%>%`

  url = paste0('http://www.espn.com/', sex, '-college-basketball/teams')
  
  cells = xml2::read_html(url) %>%
    rvest::html_nodes('.mod-content > ul.medium-logos > li h5 a')
  
  name = cells %>%
    rvest::html_text(trim = TRUE)
  
  id = cells %>%
    rvest::html_attr('href') %>%
    strsplit('/') %>%
    sapply(identity) %>%
    `[`(8,)
  
  data.frame(name = name, id = id, stringsAsFactors = FALSE)
}

#' Scrape game results for a single team-year combination
#' @param year a character value representing a year
#' @param team.id an ESPN team id
#' @param sex either 'mens' or 'womens'
#' @return data.frame of game data for the team-year
#' @author eshayer
scrape.team.game.results = function(year, team.id, sex) {
  `%>%` = dplyr::`%>%`
  year = as.character(year)
  team.id = as.character(team.id)

  url = paste0('http://www.espn.com/', sex, '-college-basketball/',
               'team/schedule/_/id/', team.id, '/year/', year)
  
  rows = xml2::read_html(url) %>%
    rvest::html_nodes('.mod-content table tr:not(.colhead)')
  
  # remove tournament games
  tourney = rows %>%
    rvest::html_text(trim = TRUE) %>%
    startsWith(c("MEN'S BASKETBALL CHAMPIONSHIP",
                 "NCAA WOMEN'S CHAMPIONSHIP")) %>%
    which

  if (length(tourney) > 0) {
    rows = rows[1:(min(tourney) - 1)]
  }

  opponent.cells = rows %>%
    rvest::html_nodes('td:nth-child(2)')
  
  result.cells = rows %>%
    rvest::html_nodes('td:nth-child(3)')
  
  skip = result.cells %>%
    rvest::html_text(trim = TRUE) %in%
    c('Postponed', 'Canceled') %>%
    which
  skip = result.cells %>%
    rvest::html_node('a') %>%
    rvest::html_attr('href') %>%
    strsplit('/') %>%
    sapply(function(row) row[5] %in% c('preview', 'onair')) %>%
    which %>%
    c(skip)
  skip = result.cells %>%
    rvest::html_node('li.score') %>%
    rvest::html_text(trim = TRUE) %>%
    is.na %>%
    which %>%
    c(skip)

  if (length(skip) > 0) {
    opponent.cells = opponent.cells[-skip]
    result.cells = result.cells[-skip]
  }
  
  won = result.cells %>%
    rvest::html_node('li.game-status') %>%
    rvest::html_text(trim = TRUE) == 'W'
  score = result.cells %>%
    rvest::html_node('li.score') %>%
    rvest::html_text(trim = TRUE) %>%
    strsplit(' ') %>%
    sapply(function(row) row[1]) %>%
    strsplit('-') %>%
    sapply(identity) %>%
    t
  other = opponent.cells %>%
    rvest::html_node('li.team-name a') %>%
    rvest::html_attr('href') %>%
    strsplit('/') %>%
    sapply(function(row) row[8])
  neutral = opponent.cells %>%
    rvest::html_node('li.team-name') %>%
    rvest::html_text(trim = TRUE) %>%
    endsWith('*')
  at.or.vs = opponent.cells %>%
    rvest::html_node('li.game-status') %>%
    rvest::html_text(trim = TRUE)
  location = ifelse(neutral, 'N', ifelse(at.or.vs == 'vs', 'H', 'A'))
  ot = result.cells %>%
    rvest::html_node('li.score') %>%
    rvest::html_text(trim = TRUE) %>%
    strsplit(' ') %>%
    sapply(function(row) row[2]) %>%
    ifelse(is.na(.), '', .)
  game.id = result.cells %>%
    rvest::html_node('li.score a') %>%
    rvest::html_attr('href') %>%
    strsplit('/') %>%
    sapply(function(row) row[8])
  
  data.frame(game.id = game.id,
             primary.id = team.id,
             primary.score = score[matrix(c(1:nrow(score), ifelse(won, 1, 2)),
                                          ncol = 2, byrow = FALSE)],
             other.id = other,
             other.score = score[matrix(c(1:nrow(score), ifelse(won, 2, 1)),
                                        ncol = 2, byrow = FALSE)],
             location = location,
             ot = ot,
             stringsAsFactors = FALSE)
}
