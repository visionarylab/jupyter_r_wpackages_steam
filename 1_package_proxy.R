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


# 测试2
# 构建请求 URL
url <- paste0(
  "https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/",
  "?key=", API_key,
  "&steamid=", steam_id,
  "&include_appinfo=1",
  "&include_played_free_games=1"
)

cat("🔍 正在测试连接 Steam API...\n")

# ⏱️ 发送请求
res <- tryCatch({
  GET(url)  # ⚠️ 若未开代理可删除 use_proxy
}, error = function(e) e)


# 结果判断
if (inherits(res, "response") && status_code(res) == 200) {
  json <- fromJSON(content(res, "text", encoding = "UTF-8"))
  game_count <- json$response$game_count
  cat("✅ 成功连接 Steam API，游戏总数：", game_count, "\n")

  # 输出前几个游戏名称和游玩时长
  games <- json$response$games
  if (!is.null(games)) {
    head_df <- head(games[, c("appid", "name", "playtime_forever")])
    print(head_df)
  } else {
    cat("⚠️ 没有返回游戏列表，可能该账号设置了隐私。\n")
  }

} else if (inherits(res, "response")) {
  cat("❌ 请求失败，状态码：", status_code(res), "\n")
  cat("响应内容：\n", content(res, "text", encoding = "UTF-8"), "\n")
} else {
  cat("❌ 无法连接 Steam API：", res$message, "\n")
}


