# 配置项，需手动填写自己的Steam API、Steam ID、Notion API、Database ID
# ==== Steam API和Steam ID配置（必须获取） ====
API_key <- Sys.getenv("STEAM_WEBAPI_KEY")
steam_id <- "76561198116745916"

# ==== Notion API和Database ID（如果只想手动导入，可不获取） ====
notion_token <- Sys.getenv("NOTION_TOKEN")
database_id <- Sys.getenv("NOTION_DATABASE_ID")



# ==== 抓取Steam数据需要的包 ====
library(httr2) # 网络请求相关
library(httr) # 网络请求相关

library(rvest) # 网页和 XML 解析
library(xml2) # 网页和 XML 解析

library(dplyr) # 数据处理
library(tibble) # 数据处理
library(jsonlite) # 数据处理

library(lubridate) # 时间处理
library(openxlsx) # Excel 导出

# ==== 将导出数据上传至Notion所需要的包（如果只想手动导入，可不加载） ====
library(cli)  # 命令行美化输出
library(glue)  # 字符串拼接（提示消息、上传状态）



# ==== 获取拥有的游戏列表（支持 API Key 和 Steam ID）====
get_owned_games <- function(API_key, steam_id) {
  
  url <- paste0("https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/?key=",
                API_key, "&steamid=", steam_id, "&include_appinfo=1")
  
  res <- tryCatch({
    json_raw <- request(url) |>
      req_options(timeout = 30) |>
      req_retry(max_tries = 3) |>
      req_perform() |>
      resp_body_string()
    
    fromJSON(json_raw)
  }, error = function(e) {
    message("❌ get_owned_games() 错误：", e$message)
    return(NULL)
  })
  
  if (is.null(res$response$games)) return(tibble())
  
  games <- res$response$games
  df <- bind_rows(games) |> 
    select(appid, name, playtime_forever, rtime_last_played)
  
  return(df)
}





# ==== 获取拥有的游戏列表（支持 API Key 和 Steam ID）====
get_owned_games2 <- function(API_key, steam_id) {
  
  url <- paste0("https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/?key=",
                API_key, "&steamid=", steam_id, "&include_appinfo=1")
  
  res <- tryCatch({
    json_raw <- request(url) |>
      req_options(timeout = 30) |>
      req_retry(max_tries = 3) |>
      req_perform() |>
      resp_body_string()
    
    fromJSON(json_raw)
  }, error = function(e) {
    message("❌ get_owned_games() 错误：", e$message)
    return(NULL)
  })
  
  if (is.null(res$response$games)) return(tibble())
  
  games <- res$response$games
  return (games)
}

  games <- get_owned_games2(API_key, steam_id)
  if (!is.null(games)) {
    head_df <- head(games[, c("appid", "name", "playtime_forever")])
    print(head_df)
  } else {
    cat("⚠️ 没有返回游戏列表2 \n")
  }
