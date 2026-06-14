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

# ==== 使用 XML 页面方式抓取完整游戏列表（适配静态网页）====
# 推荐使用官方 API 获取游玩时间和最后游玩时间（get_owned_games）
get_all_games_web <- function(user_id = steam_id) {
  
  base_url <- if (grepl("^\\d+$", user_id)) {
    paste0("https://steamcommunity.com/profiles/", user_id, "/games?xml=1")
  } else {
    paste0("https://steamcommunity.com/id/", user_id, "/games?xml=1")
  }
  
  page <- tryCatch(read_xml(base_url), error = function(e) {
    message("❌ 无法访问 Steam XML 游戏库：", e$message)
    return(NULL)
  })
  
  if (is.null(page)) return(data.frame())
  
  game_nodes <- xml_find_all(page, ".//games/game")
  if (length(game_nodes) == 0) {
    message("⚠️ XML 页面无游戏数据")
    return(data.frame())
  }
  
  # 逐个游戏提取字段
  df <- tibble(
    appid = as.integer(xml_text(xml_find_all(game_nodes, "appID"))), #获取游戏ID
    name_web = xml_text(xml_find_all(game_nodes, "name")), # 获取网页抓取的游戏名称
    hours_total_web = sapply(game_nodes, function(node) { 
      txt <- xml_text(xml_find_first(node, "hoursOnRecord")) # 获取网页抓取的游戏时间（小时）
      ifelse(nzchar(txt), as.numeric(gsub(",", "", txt)), NA_real_)
    })
  )
  
  message(sprintf("✅ 成功抓取 XML 游戏库：共 %d 个游戏", nrow(df)))
  return(df)
}

# ==== 合并网页与 API 获取的游戏列表 ====
merge_api_and_web_games <- function(api_games, web_games) {
  write.csv(api_games, "api_games_debug.csv", row.names = FALSE)
  write.csv(web_games, "web_games_debug.csv", row.names = FALSE)
  
  # 从网页抓取中只保留游戏ID、网页中的游戏名和网页时长（小时）
  web_games <- web_games |> select(appid, name_web, hours_total_web)
  
  combined <- full_join(api_games, web_games, by = "appid")
  
  # 如果 API 的playtime_forever（分钟）缺失，尝试使用网页时长 * 60 补足
  combined <- combined |> mutate(
    playtime_forever = ifelse(
      is.na(playtime_forever) & !is.na(hours_total_web),
      round(hours_total_web * 60),
      playtime_forever
    ),
    name = coalesce(name, name_web), # 优先使用 API 名称，否则网页名
    source = case_when(
      !is.na(playtime_forever) & !is.na(name_web) ~ "两者都有",
      !is.na(playtime_forever)                   ~ "API",
      !is.na(name_web)                           ~ "网页",
      TRUE                                       ~ "未知"
    )
  )
  
  # 移除网页字段，避免后续干扰
  combined <- combined |> select(appid, name, source, playtime_forever, rtime_last_played)
  
  return(combined)
}

# ==== 获取成就信息 ====
get_achievements <- function(appid) {
  # 构建 API 请求 URL
  url <- paste0("https://api.steampowered.com/ISteamUserStats/GetPlayerAchievements/v1/?key=",
                API_key, "&steamid=", steam_id, "&appid=", appid)
  
  # 执行请求，失败返回 NULL
  res <- tryCatch({
    request(url) |> req_options(timeout = 20) |> req_perform() |> resp_body_json()
  }, error = function(e) return(NULL))
  
  # 判断成就结构，可能为 NULL 或空
  achs <- res$playerstats$achievements
  if (is.null(achs) || !is.list(achs)) return(NULL)
  
  # 将成就数据转换为 data.frame
  bind_rows(achs)
}

# 获取封面
get_cover_url <- function(appid) {
  base <- "https://cdn.cloudflare.steamstatic.com/steam/apps/"
  urls <- c(
    paste0(base, appid, "/capsule_616x353.jpg"), # 更适配Notion画廊
    paste0(base, appid, "/header.jpg")  # 备用
  )
  
  for (url in urls) {
    res <- httr::HEAD(url)
    if (httr::status_code(res) == 200) return(url)
  }
  return(NA)  # 都找不到，返回 NA
}
                  
# ==== 获取商店信息 ====
get_store_info <- function(appid) {
  
  # 辅助函数：根据地区与语言抓取数据
  fetch_store_data <- function(appid, cc, lang) {
    api_url <- paste0("https://store.steampowered.com/api/appdetails?appids=", appid,
                      "&cc=", cc, "&l=", lang)
    res <- tryCatch({
      request(api_url) |> req_perform() |> resp_body_json()
    }, error = function(e) {
      message(sprintf("❌ [%s] API 请求失败：%s", cc, e$message))
      return(NULL)
    })
    
    if (is.null(res)) return(NULL)
    
    entry <- res[[as.character(appid)]]
    
    if (!is.null(entry) && isTRUE(entry$success) && !is.null(entry$data)) {
      return(entry$data)
    } else {
      return(NULL)
    }
  }
  
  # 优先尝试中国区
  data <- fetch_store_data(appid, "cn", "zh-cn")
  
  if (is.null(data)) {
    message(sprintf("⚠️ AppID [%s] 在中国区不可用，尝试美国区", appid))
    data <- fetch_store_data(appid, "us", "en")
    region <- "US"
  } else {
    region <- "CN"
  }
  
  if (is.null(data)) {
    message(sprintf("❌ AppID [%s] 在所有区域都不可用", appid))
    return(list(NA, NA, NA, NA, NA, NA, NA, NA, appid, region, NA))
  }
  
  # 商店页面 HTML，尝试获取中文名与标签
  page_url <- paste0("https://store.steampowered.com/app/", appid, "/?l=schinese")
  headers <- c("Cookie" = "birthtime=568022401; lastagecheckage=1-January-1988")
  
  html <- tryCatch({
    read_html(httr::GET(page_url, httr::add_headers(.headers = headers)))
  }, error = function(e) NA)
  
  # 提取商店标签
  tags <- tryCatch({
    if (!inherits(html, "xml_missing") && !is.na(html)) {
      tag_nodes <- html_elements(html, ".glance_tags.popular_tags a.app_tag")
      tag_text <- html_text(tag_nodes, trim = TRUE)[1:min(5, length(tag_nodes))] # 只抓取前5个商店标签
      paste(tag_text, collapse = ", ")
    } else {
      ""
    }
  }, error = function(e) {
    message(sprintf("⚠️ [标签提取失败] AppID %s: %s", appid, e$message))
    ""
  })
  
  # 提取中文标题（如果有）
  cn_title <- tryCatch({
    if (!inherits(html, "xml_missing") && !is.na(html)) {
      html_title <- html_element(html, ".apphub_AppName")
      html_text(html_title, trim = TRUE)
    } else {
      NA_character_
    }
  }, error = function(e) NA_character_)
  
  # 提取其余字段
  dev <- tryCatch(paste(data$developers, collapse = ", "), error = function(e) NA) #开发商
  pub <- tryCatch(paste(data$publishers, collapse = ", "), error = function(e) NA) #发行商
  released <- tryCatch(data$release_date$date, error = function(e) NA) #发售日期
  
  # 获取价格和币种
  price_initial <- tryCatch(data$price_overview$initial, error = function(e) NA) #原价
  price_final <- tryCatch(data$price_overview$final, error = function(e) NA) #当前价格
  currency <- tryCatch(data$price_overview$currency, error = function(e) NA) #币种
  
  # 自动根据币种格式化价格
  format_price <- function(price, currency) {
    if (is.null(price) || is.na(price)) return("未知")
    symbol <- switch(currency,
                     "CNY" = "￥", 
                     "USD" = "$", 
                     "EUR" = "€", 
                     "GBP" = "£", 
                     "")
    paste0(symbol, sprintf("%.2f", price / 100))
  }
  
  price_origin <- format_price(price_initial, currency) # 原价（带单位）
  price_now     <- format_price(price_final, currency) # 当前价格（带单位）
  
  # 折扣力度
  discount  <- tryCatch(data$price_overview$discount_percent, error = function(e) NA) 
  discount_txt <- if (!is.null(discount) && length(discount) > 0 && !is.na(discount)) paste0("-", discount, "%") else "无折扣"
  
  content   <- tryCatch(data$type, error = function(e) NA) # 数据来源
  
  message(sprintf("✅ [%s] 获取成功（区域：%s）：%s", appid, region, cn_title))
  
  return(list(
    dev, pub, released, price_now, 
    discount_txt, tags, content, cn_title, 
    appid, region, price_origin))
}

# ==== 主流程封装函数 ====
fetch_and_merge_all_games <- function(api_key = API_key, user_id = steam_id) {
  message("📦 正在获取 Steam 游戏数据...")
  api_games <- tryCatch({
    get_owned_games(api_key, user_id)
  }, error = function(e) {
    message("❌ API 获取失败：", e$message)
    data.frame()
  })
  
  web_games <- get_all_games_web(user_id)
  games <- merge_api_and_web_games(api_games, web_games)
  message(sprintf("🎮 合并完成：共 %d 个游戏", nrow(games)))
  return(games)
}

games <- fetch_and_merge_all_games() # 获得API+网页抓取数据
games <- distinct(games, appid, .keep_all = TRUE) #去掉重复（若有）
result <- list()

# ==== 主处理逻辑 ====
# 如果担心出错的话可以先跑21行试试，用test替换下面的games
# 例如：games_test <- games[30:50, ] #选取第20行-50行的数据

for (i in seq_len(nrow(games))) { 
  game <- games[i, ]
  appid <- game$appid
  cat(sprintf("[%d/%d] 正在处理：%s\n", i, nrow(games), game$name))
  
  mins <- game$playtime_forever
  hours <- if (!is.na(mins)) round(mins / 60, 2) else NA_real_
  
  playtime_display <- if (is.na(mins) || mins == 0) {
    "0"
  } else if (mins < 60) {
    paste0(mins, " 分钟") # 若游玩时间不超过1小时，则时间单位为”分钟“
  } else {
    paste0(hours, " 小时") 
  }
  
  last_played <- if (!is.na(mins) && mins > 0 && !is.na(game$rtime_last_played)) {
    as_datetime(game$rtime_last_played)
  } else {
    NA
  }
  
  ach <- get_achievements(appid)
  if (is.null(ach)) {
    total_ach <- 0
    unlocked_ach <- 0
    first_ach_time <- "此版本无成就"
  } else {
    total_ach <- nrow(ach)
    unlocked_ach <- sum(ach$achieved == 1)
    times <- ach$unlocktime[ach$achieved == 1]
    first_ach_time <- if (length(times) > 0) as.character(as_datetime(min(times))) else NA
  }
  
  store <- get_store_info(appid)
  cover_url <- get_cover_url(appid)
  cn_name <- if (!is.null(store[[8]]) && !is.na(store[[8]])) store[[8]] else game$name
  en_name <- if (!is.null(game$name) && !is.na(game$name) && grepl("[A-Za-z]", game$name) && (is.null(store[[8]]) || is.na(store[[8]]) || store[[8]] != game$name)) game$name else NA_character_
  
  result[[i]] <- tibble(
    游戏名称 = cn_name,
    游戏英文名 = en_name,
    游戏ID = appid,
    游玩时间 = playtime_display,
    总时长小时 = hours,
    最后游玩 = last_played,
    成就总数 = total_ach,
    已解锁成就 = unlocked_ach,
    首个成就时间 = first_ach_time,
    开发商 = store[[1]],
    发行商 = store[[2]],
    发售日期 = store[[3]],
    原价 = store[[11]],
    当前价格 = store[[4]],
    当前折扣 = store[[5]],
    商店标签 = store[[6]],
    来源 = game$source,
    内容类型 = case_when(
      store[[7]] == "game"  ~ "游戏本体",
      store[[7]] == "dlc"   ~ "DLC",
      store[[7]] == "music" ~ "原声音轨",
      store[[7]] == "demo"  ~ "试玩版",
      TRUE                  ~ "其它"
    ),
    封面 = cover_url
  )
  Sys.sleep(1)
}

# 合并（单个账户）
# 这个final_df也是后面用来上传Notion所需要的数据
final_df <- bind_rows(result) 

# 💾 导出 Excel
# 保存在E盘，可以根据自己需求修改保存位置
# 若手动导入Notion，请将Excel文件另存为CSV格式
write.xlsx(final_df, file = "Steam Data.xlsx", encoding = "UTF-8") 

# 合并（假设现在有两个账户的数据）
# 这个final_df也是后面用来上传Notion所需要的数据
final_df1 <- bind_rows(result1) 
final_df2 <- bind_rows(result2) 

# 💾 导出 Excel 进行备份
# 可以根据自己需求修改保存位置，比如保存在E盘"E:/Steam Data1.xlsx"
# 若手动导入Notion，请将Excel文件另存为CSV格式
write.xlsx(final_df1, file = "Steam Data1.xlsx", encoding = "UTF-8") 
write.xlsx(final_df2, file = "Steam Data2.xlsx", encoding = "UTF-8")                        