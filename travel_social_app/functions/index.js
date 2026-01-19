const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");
const {GoogleGenerativeAI} = require("@google/generative-ai");
const axios = require("axios");

admin.initializeApp();

// Define secrets
const geminiApiKey = defineSecret("GEMINI_API_KEY");
const openweatherApiKey = defineSecret("OPENWEATHER_API_KEY");

// Constants
const MAX_MESSAGES_IN_SESSION = 20;
const SESSION_COLLECTION = "ai_chat_sessions";

/**
 * Cloud Function tự động gửi push notification
 * khi có notification mới được tạo trong Firestore
 */
exports.sendNotificationOnCreate = onDocumentCreated(
    {
      document: "notifications/{notificationId}",
      region: "asia-southeast1", // Chọn region gần Việt Nam
    },
    async (event) => {
      try {
        const notification = event.data.data();
        const notificationId = event.params.notificationId;

        console.log("New notification created:", notificationId);
        console.log("Notification data:", notification);

        // Lấy FCM token của user nhận notification
        const userDoc = await admin
            .firestore()
            .collection("users")
            .doc(notification.userId)
            .get();

        if (!userDoc.exists) {
          console.log("User not found:", notification.userId);
          return null;
        }

        const fcmToken = userDoc.data().fcmToken;

        if (!fcmToken) {
          console.log("User has no FCM token:", notification.userId);
          return null;
        }

        // Tạo FCM message
        const message = {
          token: fcmToken,
          notification: {
            title: notification.title,
            body: notification.body,
            imageUrl: notification.imageUrl || undefined,
          },
          data: {
            notificationId: notificationId,
            type: notification.type,
            ...notification.data,
          },
          android: {
            priority: "high",
            notification: {
              channelId: "travel_social_app_channel",
              sound: "default",
              priority: "high",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        };

        // Gửi notification
        const response = await admin.messaging().send(message);
        console.log("✅ Notification sent successfully:", response);

        return {success: true, messageId: response};
      } catch (error) {
        console.error("❌ Error sending notification:", error);
        return {success: false, error: error.message};
      }
    },
);

/**
 * Helper: Lấy thông tin thời tiết từ OpenWeather API
 * @param {string} cityName - Tên thành phố
 * @param {string} apiKey - OpenWeather API key
 * @return {Promise<Object>} - Dữ liệu thời tiết
 */
async function getWeatherData(cityName, apiKey) {
  try {
    const url = `https://api.openweathermap.org/data/2.5/weather`;
    const params = {
      q: cityName,
      appid: apiKey,
      units: "metric", // Độ C
      lang: "vi", // Tiếng Việt
    };

    const response = await axios.get(url, {params});
    const data = response.data;

    return {
      city: data.name,
      temperature: data.main.temp,
      feelsLike: data.main.feels_like,
      humidity: data.main.humidity,
      description: data.weather[0].description,
      windSpeed: data.wind.speed,
      icon: data.weather[0].icon,
    };
  } catch (error) {
    console.error("Error fetching weather:", error.message);
    return null;
  }
}

/**
 * Helper: Kiểm tra xem câu hỏi có liên quan đến thời tiết không
 * @param {string} message - Tin nhắn người dùng
 * @return {string|null} - Tên thành phố nếu có, null nếu không
 */
function extractCityFromWeatherQuery(message) {
  const lowerMsg = message.toLowerCase();

  // Keywords thời tiết
  const weatherKeywords = [
    "thời tiết",
    "nhiệt độ",
    "nóng",
    "lạnh",
    "mưa",
    "nắng",
    "weather",
    "temperature",
  ];

  const hasWeatherKeyword = weatherKeywords.some(
      (keyword) => lowerMsg.includes(keyword),
  );

  if (!hasWeatherKeyword) return null;

  // Danh sách thành phố phổ biến
  const cities = [
    "hà nội",
    "hồ chí minh",
    "đà nẵng",
    "hải phòng",
    "cần thơ",
    "nha trang",
    "đà lạt",
    "vũng tàu",
    "huế",
    "sài gòn",
    "hanoi",
    "saigon",
    "ho chi minh",
    "danang",
    "haiphong",
    "cantho",
  ];

  for (const city of cities) {
    if (lowerMsg.includes(city)) {
      // Map sang tên tiếng Anh cho API
      const cityMap = {
        "hà nội": "Hanoi",
        "hanoi": "Hanoi",
        "hồ chí minh": "Ho Chi Minh",
        "sài gòn": "Ho Chi Minh",
        "saigon": "Ho Chi Minh",
        "ho chi minh": "Ho Chi Minh",
        "đà nẵng": "Da Nang",
        "danang": "Da Nang",
        "hải phòng": "Hai Phong",
        "haiphong": "Hai Phong",
        "cần thơ": "Can Tho",
        "cantho": "Can Tho",
        "nha trang": "Nha Trang",
        "đà lạt": "Da Lat",
        "vũng tàu": "Vung Tau",
        "huế": "Hue",
      };
      return cityMap[city] || city;
    }
  }

  return null;
}

/**
 * Helper: Lấy hoặc tạo session chat
 * @param {string} userId - User ID
 * @param {string} sessionId - Session ID (optional)
 * @return {Promise<Object>} - Session data với messages
 */
async function getOrCreateSession(userId, sessionId = null) {
  const db = admin.firestore();

  if (sessionId) {
    // Lấy session hiện có
    const sessionDoc = await db
        .collection(SESSION_COLLECTION)
        .doc(sessionId)
        .get();

    if (sessionDoc.exists) {
      return {
        sessionId: sessionDoc.id,
        ...sessionDoc.data(),
      };
    }
  }

  // Tạo session mới
  const newSession = {
    userId: userId,
    messages: [],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const sessionRef = await db.collection(SESSION_COLLECTION).add(newSession);

  return {
    sessionId: sessionRef.id,
    ...newSession,
  };
}

/**
 * Helper: Lưu message vào session và giữ tối đa MAX_MESSAGES_IN_SESSION
 * @param {string} sessionId - Session ID
 * @param {Object} userMessage - Message từ user
 * @param {Object} assistantMessage - Message từ assistant
 */
async function saveMessagesToSession(
    sessionId,
    userMessage,
    assistantMessage,
) {
  const db = admin.firestore();
  const sessionRef = db.collection(SESSION_COLLECTION).doc(sessionId);

  const sessionDoc = await sessionRef.get();
  let messages = sessionDoc.data()?.messages || [];

  // Thêm messages mới
  messages.push(userMessage, assistantMessage);

  // Giữ tối đa MAX_MESSAGES_IN_SESSION messages gần nhất
  if (messages.length > MAX_MESSAGES_IN_SESSION) {
    messages = messages.slice(-MAX_MESSAGES_IN_SESSION);
  }

  await sessionRef.update({
    messages: messages,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Cloud Function: Chat với AI Travel Assistant
 * Endpoint: chatWithAssistant
 */
exports.chatWithAssistant = onCall(
    {
      region: "asia-southeast1",
      secrets: [geminiApiKey, openweatherApiKey],
      // enforceAppCheck: true, // Uncomment for production
    },
    async (request) => {
      // Initialize Gemini AI with secret
      const genAI = new GoogleGenerativeAI(geminiApiKey.value());
      
      try {
        // Validate input
        if (!request.auth) {
          throw new HttpsError(
              "unauthenticated",
              "User must be authenticated",
          );
        }

        const {message, sessionId, userContext} = request.data;

        if (!message || typeof message !== "string") {
          throw new HttpsError("invalid-argument", "Message is required");
        }

        const userId = request.auth.uid;

        console.log(`📩 New message from user ${userId}: "${message}"`);
        if (userContext) {
          console.log(`📋 User context provided: ${userContext.substring(0, 200)}...`);
        }

        // 1. Lấy hoặc tạo session
        const session = await getOrCreateSession(userId, sessionId);
        console.log(`📂 Session ID: ${session.sessionId}`);

        // 2. Kiểm tra xem có cần gọi Weather API không
        let weatherContext = "";
        const cityName = extractCityFromWeatherQuery(message);

        if (cityName) {
          console.log(`🌤️ Fetching weather for: ${cityName}`);
          const weatherData = await getWeatherData(cityName, openweatherApiKey.value());

          if (weatherData) {
            weatherContext = `
[Thông tin thời tiết thực tế - ${weatherData.city}]
- Nhiệt độ: ${weatherData.temperature}°C (Cảm giác như ${weatherData.feelsLike}°C)
- Mô tả: ${weatherData.description}
- Độ ẩm: ${weatherData.humidity}%
- Tốc độ gió: ${weatherData.windSpeed} m/s
`;
            console.log("✅ Weather data fetched successfully");
          }
        }

        // 3. Chuẩn bị context cho Gemini
        // Lấy thời gian hiện tại (Việt Nam UTC+7)
        const currentTime = new Date(Date.now() + (7 * 60 * 60 * 1000));
        const dateStr = currentTime.toLocaleDateString("vi-VN", {
          weekday: "long",
          year: "numeric",
          month: "long",
          day: "numeric",
        });
        const timeStr = currentTime.toLocaleTimeString("vi-VN", {
          hour: "2-digit",
          minute: "2-digit",
        });

        const systemPrompt = `Bạn là TravelBot - trợ lý du lịch thông minh và cá nhân hóa tại Việt Nam.

📅 THÔNG TIN THỜI GIAN:
- Ngày hiện tại: ${dateStr}
- Giờ hiện tại: ${timeStr} (Múi giờ Việt Nam)

${userContext ? userContext : ""}

🎯 VAI TRÒ & PHẠM VI:
- Chỉ trả lời các câu hỏi liên quan đến DU LỊCH
- Tập trung vào các địa điểm, trải nghiệm du lịch tại Việt Nam
- Có thể tư vấn về du lịch quốc tế nhưng ưu tiên Việt Nam
- Từ chối lịch sự các câu hỏi ngoài phạm vi du lịch
- ƯU TIÊN sử dụng thông tin từ THÔNG TIN NGƯỜI DÙNG và danh sách địa điểm có sẵn trong hệ thống

💡 NHIỆM VỤ CHÍNH:
1. Tư vấn địa điểm du lịch (bãi biển, núi non, di tích lịch sử)
2. Gợi ý khách sạn, resort, nhà nghỉ phù hợp ngân sách
3. Giới thiệu ẩm thực địa phương, nhà hàng nổi tiếng
4. Cung cấp thông tin thời tiết khi có dữ liệu
5. Lập lịch trình du lịch chi tiết (1-7 ngày)
6. Chia sẻ kinh nghiệm: đi lại, mua sắm, giá cả
7. Tư vấn hoạt động: lặn biển, leo núi, tham quan
8. Hướng dẫn văn hóa, phong tục địa phương

📝 NGUYÊN TẮC TRẢ LỜI:
- Ngắn gọn (2-5 câu), dễ hiểu, TRỪ KHI được yêu cầu chi tiết
- Thực tế, có thể áp dụng được
- CỰC KỲ ƯU TIÊN đề xuất các địa điểm trong danh sách "ĐỊA ĐIỂM GỢI Ý" và "ĐỊA ĐIỂM PHỔ BIẾN"
- Cân nhắc VỊ TRÍ HIỆN TẠI và SỞ THÍCH của người dùng
- Cung cấp giá tham khảo nếu có thể
- Gợi ý nhiều lựa chọn (budget, mid-range, luxury)
- Sử dụng emoji phù hợp để sinh động
- Luôn kết thúc bằng "Bạn cần tôi tư vấn thêm gì không?"

⚠️ KHÔNG TRẢ LỜI:
- Các câu hỏi về chính trị, tôn giáo nhạy cảm
- Lập trình, toán học, khoa học không liên quan du lịch
- Y tế, pháp lý (chỉ lời khuyên chung cho du khách)
- Nội dung không phù hợp, bạo lực

${weatherContext ? "\n🌤️ THÔNG TIN THỜI TIẾT:\n" + weatherContext : ""}`;


        // Build conversation history
        const conversationHistory = session.messages
            .map((msg) => ({
              role: msg.role,
              parts: [{text: msg.content}],
            }))
            .slice(-10); // Chỉ lấy 10 messages gần nhất cho context

        // 4. Gọi Gemini API với retry logic
        let assistantReply;
        const models = [
          "gemini-2.5-flash", // Primary model
          "gemini-2.0-flash", // Fallback model
          "gemini-flash-latest", // Last resort
        ];

        let lastError;
        for (const modelName of models) {
          try {
            console.log(`🤖 Trying model: ${modelName}`);
            const model = genAI.getGenerativeModel({model: modelName});

            const chat = model.startChat({
              history: [
                {
                  role: "user",
                  parts: [{text: systemPrompt}],
                },
                {
                  role: "model",
                  parts: [{text: "Xin chào! Tôi là trợ lý du lịch của bạn. Tôi có thể giúp gì cho bạn hôm nay?"}],
                },
                ...conversationHistory,
              ],
              generationConfig: {
                maxOutputTokens: 2048, // Tăng lên để hỗ trợ response dài hơn
                temperature: 0.7,
              },
            });

            const result = await chat.sendMessage(message);
            const response = result.response;
            assistantReply = response.text();

            console.log(`✅ Success with ${modelName}: "${assistantReply.substring(0, 100)}..."`);
            break; // Success, exit loop
          } catch (error) {
            console.log(`❌ Model ${modelName} failed:`, error.message);
            lastError = error;

            // If it's a 503 (overloaded), wait and retry
            if (error.message?.includes("503") || error.message?.includes("overloaded")) {
              console.log("⏳ Waiting 2 seconds before trying next model...");
              await new Promise((resolve) => setTimeout(resolve, 2000));
            }
            // Continue to next model
          }
        }

        // If all models failed, throw error
        if (!assistantReply) {
          throw new Error(
              `All models failed. Last error: ${lastError?.message || "Unknown error"}`,
          );
        }

        // 5. Lưu messages vào Firestore
        // Note: Không dùng serverTimestamp() trong array, dùng Date object
        // Thời gian Việt Nam (UTC+7)
        const now = new Date(Date.now() + (7 * 60 * 60 * 1000));
        
        const userMessage = {
          role: "user",
          content: message,
          timestamp: now,
        };

        const assistantMessage = {
          role: "model",
          content: assistantReply,
          timestamp: now,
        };

        await saveMessagesToSession(
            session.sessionId,
            userMessage,
            assistantMessage,
        );

        // 6. Trả về response
        return {
          success: true,
          sessionId: session.sessionId,
          message: assistantReply,
          weatherData: cityName ? weatherContext : null,
        };
      } catch (error) {
        console.error("❌ Error in chatWithAssistant:", error);
        throw new HttpsError("internal", error.message);
      }
    },
);

/**
 * Cloud Function: Reset chat session
 * Endpoint: resetChatSession
 */
exports.resetChatSession = onCall(
    {
      region: "asia-southeast1",
    },
    async (request) => {
      try {
        if (!request.auth) {
          throw new HttpsError(
              "unauthenticated",
              "User must be authenticated",
          );
        }

        const {sessionId} = request.data;

        if (!sessionId) {
          throw new HttpsError("invalid-argument", "Session ID is required");
        }

        const db = admin.firestore();
        await db.collection(SESSION_COLLECTION).doc(sessionId).delete();

        console.log(`🗑️ Session ${sessionId} deleted`);

        return {
          success: true,
          message: "Session reset successfully",
        };
      } catch (error) {
        console.error("❌ Error resetting session:", error);
        throw new HttpsError("internal", error.message);
      }
    },
);

/**
 * Cloud Function: Lấy danh sách chat sessions của user
 * Endpoint: getChatSessions
 */
exports.getChatSessions = onCall(
    {
      region: "asia-southeast1",
    },
    async (request) => {
      try {
        if (!request.auth) {
          throw new HttpsError(
              "unauthenticated",
              "User must be authenticated",
          );
        }

        const userId = request.auth.uid;
        const db = admin.firestore();

        // Lấy tất cả sessions của user, sắp xếp theo updatedAt
        const sessionsSnapshot = await db
            .collection(SESSION_COLLECTION)
            .where("userId", "==", userId)
            .orderBy("updatedAt", "desc")
            .limit(50) // Giới hạn 50 sessions gần nhất
            .get();

        const sessions = [];
        sessionsSnapshot.forEach((doc) => {
          const data = doc.data();
          const lastMessage = data.messages && data.messages.length > 0 ?
            data.messages[data.messages.length - 1].content : "";

          sessions.push({
            sessionId: doc.id,
            createdAt: data.createdAt,
            updatedAt: data.updatedAt,
            messageCount: data.messages ? data.messages.length : 0,
            lastMessage: lastMessage.substring(0, 100), // Preview 100 ký tự
          });
        });

        console.log(`📋 Found ${sessions.length} sessions for user ${userId}`);

        return {
          success: true,
          sessions: sessions,
        };
      } catch (error) {
        console.error("❌ Error getting chat sessions:", error);
        throw new HttpsError("internal", error.message);
      }
    },
);

/**
 * Cloud Function: Lấy chi tiết một session (messages)
 * Endpoint: getSessionDetail
 */
exports.getSessionDetail = onCall(
    {
      region: "asia-southeast1",
    },
    async (request) => {
      try {
        if (!request.auth) {
          throw new HttpsError(
              "unauthenticated",
              "User must be authenticated",
          );
        }

        const {sessionId} = request.data;
        const userId = request.auth.uid;

        if (!sessionId) {
          throw new HttpsError("invalid-argument", "Session ID is required");
        }

        const db = admin.firestore();
        const sessionDoc = await db
            .collection(SESSION_COLLECTION)
            .doc(sessionId)
            .get();

        if (!sessionDoc.exists) {
          throw new HttpsError("not-found", "Session not found");
        }

        const sessionData = sessionDoc.data();

        // Verify quyền truy cập
        if (sessionData.userId !== userId) {
          throw new HttpsError(
              "permission-denied",
              "You don't have permission to access this session",
          );
        }

        console.log(`📖 Retrieved session ${sessionId} for user ${userId}`);

        return {
          success: true,
          session: {
            sessionId: sessionDoc.id,
            messages: sessionData.messages || [],
            createdAt: sessionData.createdAt,
            updatedAt: sessionData.updatedAt,
          },
        };
      } catch (error) {
        console.error("❌ Error getting session detail:", error);
        throw new HttpsError("internal", error.message);
      }
    },
);

// ============================================================================
// ADMIN VIOLATION MANAGEMENT - EMAIL NOTIFICATIONS
// ============================================================================

/**
 * Helper: Tạo Nodemailer transporter
 * @return {Object} - Nodemailer transporter
 */
function createEmailTransporter() {
  return nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: gmailUser.value(),
      pass: gmailPassword.value(),
    },
  });
}

/**
 * Helper: HTML template cho email cảnh cáo
 * @param {Object} data - User và violation data
 * @return {string} - HTML content
 */
function getWarningEmailTemplate(data) {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: 'Segoe UI', Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9; }
    .header { background-color: #ff9800; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
    .content { background-color: white; padding: 30px; border-radius: 0 0 8px 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .warning-box { background-color: #fff3cd; border-left: 4px solid #ff9800; padding: 15px; margin: 20px 0; }
    .info-table { width: 100%; border-collapse: collapse; margin: 20px 0; }
    .info-table td { padding: 10px; border-bottom: 1px solid #eee; }
    .info-table td:first-child { font-weight: bold; width: 40%; color: #666; }
    .footer { text-align: center; margin-top: 20px; color: #666; font-size: 14px; }
    .button { display: inline-block; padding: 12px 24px; background-color: #2196F3; color: white; text-decoration: none; border-radius: 4px; margin: 20px 0; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>⚠️ CẢNH CÁO VI PHẠM</h1>
    </div>
    <div class="content">
      <p>Xin chào <strong>${data.userName}</strong>,</p>
      
      <div class="warning-box">
        <p><strong>Tài khoản của bạn đã nhận được cảnh cáo vi phạm nội quy cộng đồng Travel Social App.</strong></p>
      </div>
      
      <table class="info-table">
        <tr>
          <td>Loại vi phạm:</td>
          <td><strong>${data.violationTypeText}</strong></td>
        </tr>
        <tr>
          <td>Lý do:</td>
          <td>${data.violationReason}</td>
        </tr>
        <tr>
          <td>Ghi chú từ Admin:</td>
          <td>${data.adminNote || "Không có"}</td>
        </tr>
        <tr>
          <td>Điểm bị trừ:</td>
          <td><span style="color: red; font-weight: bold;">${data.penaltyPoints} điểm</span></td>
        </tr>
        <tr>
          <td>Số lần cảnh cáo:</td>
          <td><span style="color: #ff9800; font-weight: bold;">${data.warningCount} lần</span></td>
        </tr>
        <tr>
          <td>Thời gian:</td>
          <td>${data.timestamp}</td>
        </tr>
      </table>
      
      <h3>⚠️ Lưu ý quan trọng:</h3>
      <ul>
        <li>Đây là <strong>cảnh cáo chính thức</strong> từ hệ thống.</li>
        <li>Nếu tiếp tục vi phạm, tài khoản của bạn có thể bị <strong>tạm khóa hoặc xóa vĩnh viễn</strong>.</li>
        <li>Vui lòng tuân thủ <a href="https://travelsocialapp.com/community-guidelines">nội quy cộng đồng</a>.</li>
        <li>Điểm của bạn đã bị trừ ${data.penaltyPoints} điểm.</li>
      </ul>
      
      <p>Nếu bạn cho rằng đây là nhầm lẫn, vui lòng liên hệ:</p>
      <a href="mailto:support@travelsocialapp.com" class="button">Liên hệ hỗ trợ</a>
      
      <div class="footer">
        <p>Email này được gửi tự động từ hệ thống Travel Social App.<br>
        Vui lòng không trả lời email này.</p>
      </div>
    </div>
  </div>
</body>
</html>
  `;
}

/**
 * Helper: HTML template cho email cấm tài khoản
 * @param {Object} data - User và violation data
 * @return {string} - HTML content
 */
function getBanEmailTemplate(data) {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: 'Segoe UI', Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f9f9f9; }
    .header { background-color: #d32f2f; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
    .content { background-color: white; padding: 30px; border-radius: 0 0 8px 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .ban-box { background-color: #ffebee; border-left: 4px solid #d32f2f; padding: 15px; margin: 20px 0; }
    .info-table { width: 100%; border-collapse: collapse; margin: 20px 0; }
    .info-table td { padding: 10px; border-bottom: 1px solid #eee; }
    .info-table td:first-child { font-weight: bold; width: 40%; color: #666; }
    .footer { text-align: center; margin-top: 20px; color: #666; font-size: 14px; }
    .button { display: inline-block; padding: 12px 24px; background-color: #2196F3; color: white; text-decoration: none; border-radius: 4px; margin: 20px 0; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🚫 TÀI KHOẢN BỊ CẤM</h1>
    </div>
    <div class="content">
      <p>Xin chào <strong>${data.userName}</strong>,</p>
      
      <div class="ban-box">
        <p><strong>Tài khoản của bạn đã bị cấm truy cập vào Travel Social App do vi phạm nghiêm trọng nội quy cộng đồng.</strong></p>
      </div>
      
      <table class="info-table">
        <tr>
          <td>Loại vi phạm:</td>
          <td><strong style="color: #d32f2f;">${data.violationTypeText}</strong></td>
        </tr>
        <tr>
          <td>Lý do cấm:</td>
          <td>${data.banReason}</td>
        </tr>
        <tr>
          <td>Ghi chú từ Admin:</td>
          <td>${data.adminNote || "Không có"}</td>
        </tr>
        <tr>
          <td>Điểm bị trừ:</td>
          <td><span style="color: red; font-weight: bold;">${data.penaltyPoints} điểm</span></td>
        </tr>
        <tr>
          <td>Tổng số lần vi phạm:</td>
          <td><span style="color: #d32f2f; font-weight: bold;">${data.warningCount} lần</span></td>
        </tr>
        <tr>
          <td>Thời gian cấm:</td>
          <td>${data.timestamp}</td>
        </tr>
      </table>
      
      <h3>❌ Hậu quả:</h3>
      <ul>
        <li>Tài khoản của bạn <strong>không thể đăng nhập</strong>.</li>
        <li>Tất cả nội dung vi phạm đã bị <strong>xóa</strong>.</li>
        <li>Bạn <strong>không thể tạo tài khoản mới</strong> với email này.</li>
        <li>Quyết định này có thể là <strong>vĩnh viễn</strong>.</li>
      </ul>
      
      <h3>📞 Khiếu nại:</h3>
      <p>Nếu bạn cho rằng đây là nhầm lẫn hoặc muốn kháng nghị, vui lòng liên hệ:</p>
      <a href="mailto:support@travelsocialapp.com?subject=Khiếu%20nại%20tài%20khoản%20bị%20cấm" class="button">Gửi khiếu nại</a>
      
      <p style="color: #666; font-size: 14px; margin-top: 20px;">
        <em>Lưu ý: Chúng tôi sẽ xem xét khiếu nại trong vòng 5-7 ngày làm việc. Vui lòng cung cấp đầy đủ thông tin để hỗ trợ nhanh hơn.</em>
      </p>
      
      <div class="footer">
        <p>Email này được gửi tự động từ hệ thống Travel Social App.<br>
        Vui lòng không trả lời email này.</p>
      </div>
    </div>
  </div>
</body>
</html>
  `;
}

/**
 * Helper: Lấy text mô tả loại vi phạm
 * @param {string} violationType - Violation type code
 * @return {string} - Vietnamese text
 */
function getViolationTypeText(violationType) {
  const types = {
    "pornographic": "Nội dung khiêu dâm",
    "misinformation": "Thông tin sai lệch",
    "harassment": "Quấy rối, bắt nạt",
    "spam": "Spam, quảng cáo",
    "violence": "Bạo lực, nguy hiểm",
    "hate_speech": "Phát ngôn thù địch",
    "copyright": "Vi phạm bản quyền",
    "other": "Vi phạm khác",
  };
  return types[violationType] || violationType;
}

/**
 * Helper: Lấy điểm phạt theo loại vi phạm
 * @param {string} violationType - Violation type code
 * @return {number} - Penalty points (negative)
 */
function getPenaltyPoints(violationType) {
  const penalties = {
    "pornographic": -50,
    "misinformation": -30,
    "harassment": -40,
    "spam": -20,
    "violence": -45,
    "hate_speech": -40,
    "copyright": -35,
    "other": -25,
  };
  return penalties[violationType] || -25;
}

/**
 * Cloud Function: Gửi email cảnh cáo cho user
 * Endpoint: sendWarningEmail
 */
exports.sendWarningEmail = onCall(
    {
      region: "asia-southeast1",
      secrets: [gmailUser, gmailPassword],
    },
    async (request) => {
      try {
        // Verify admin authentication
        if (!request.auth) {
          throw new HttpsError("unauthenticated", "Must be authenticated");
        }

        const {userId, violationType, violationReason, adminNote, warningCount} = request.data;

        if (!userId || !violationType) {
          throw new HttpsError("invalid-argument", "userId and violationType are required");
        }

        const db = admin.firestore();

        // Get user data
        const userDoc = await db.collection("users").doc(userId).get();
        if (!userDoc.exists) {
          throw new HttpsError("not-found", "User not found");
        }

        const userData = userDoc.data();
        const userEmail = userData.email;
        const userName = userData.name || "Người dùng";

        if (!userEmail) {
          console.log(`⚠️ User ${userId} has no email address`);
          return {success: false, message: "User has no email address"};
        }

        // Prepare email data
        const emailData = {
          userName: userName,
          violationTypeText: getViolationTypeText(violationType),
          violationReason: violationReason || "Không có lý do cụ thể",
          adminNote: adminNote || "",
          penaltyPoints: Math.abs(getPenaltyPoints(violationType)),
          warningCount: warningCount || 1,
          timestamp: new Date().toLocaleString("vi-VN", {timeZone: "Asia/Ho_Chi_Minh"}),
        };

        // Create transporter
        const transporter = createEmailTransporter();

        // Send email
        const mailOptions = {
          from: `"Travel Social App" <${gmailUser.value()}>`,
          to: userEmail,
          subject: `⚠️ Cảnh cáo vi phạm - Travel Social App`,
          html: getWarningEmailTemplate(emailData),
        };

        const info = await transporter.sendMail(mailOptions);
        console.log(`✅ Warning email sent to ${userEmail}:`, info.messageId);

        // Log to emailLogs collection
        await db.collection("emailLogs").add({
          type: "warning",
          userId: userId,
          recipientEmail: userEmail,
          subject: mailOptions.subject,
          violationType: violationType,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          messageId: info.messageId,
          status: "sent",
        });

        return {success: true, messageId: info.messageId};
      } catch (error) {
        console.error("❌ Error sending warning email:", error);
        throw new HttpsError("internal", error.message);
      }
    },
);

/**
 * Cloud Function: Gửi email cấm tài khoản cho user
 * Endpoint: sendBanNotificationEmail
 */
exports.sendBanNotificationEmail = onCall(
    {
      region: "asia-southeast1",
      secrets: [gmailUser, gmailPassword],
    },
    async (request) => {
      try {
        // Verify admin authentication
        if (!request.auth) {
          throw new HttpsError("unauthenticated", "Must be authenticated");
        }

        const {userId, violationType, banReason, adminNote, warningCount} = request.data;

        if (!userId || !violationType) {
          throw new HttpsError("invalid-argument", "userId and violationType are required");
        }

        const db = admin.firestore();

        // Get user data
        const userDoc = await db.collection("users").doc(userId).get();
        if (!userDoc.exists) {
          throw new HttpsError("not-found", "User not found");
        }

        const userData = userDoc.data();
        const userEmail = userData.email;
        const userName = userData.name || "Người dùng";

        if (!userEmail) {
          console.log(`⚠️ User ${userId} has no email address`);
          return {success: false, message: "User has no email address"};
        }

        // Prepare email data
        const emailData = {
          userName: userName,
          violationTypeText: getViolationTypeText(violationType),
          banReason: banReason || "Vi phạm nghiêm trọng nội quy cộng đồng",
          adminNote: adminNote || "",
          penaltyPoints: Math.abs(getPenaltyPoints(violationType)),
          warningCount: warningCount || 1,
          timestamp: new Date().toLocaleString("vi-VN", {timeZone: "Asia/Ho_Chi_Minh"}),
        };

        // Create transporter
        const transporter = createEmailTransporter();

        // Send email
        const mailOptions = {
          from: `"Travel Social App" <${gmailUser.value()}>`,
          to: userEmail,
          subject: `🚫 Tài khoản bị cấm - Travel Social App`,
          html: getBanEmailTemplate(emailData),
        };

        const info = await transporter.sendMail(mailOptions);
        console.log(`✅ Ban notification email sent to ${userEmail}:`, info.messageId);

        // Log to emailLogs collection
        await db.collection("emailLogs").add({
          type: "ban",
          userId: userId,
          recipientEmail: userEmail,
          subject: mailOptions.subject,
          violationType: violationType,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          messageId: info.messageId,
          status: "sent",
        });

        return {success: true, messageId: info.messageId};
      } catch (error) {
        console.error("❌ Error sending ban email:", error);
        throw new HttpsError("internal", error.message);
      }
    },
);

/**
 * Cloud Function: Vô hiệu hóa Firebase Auth của user
 * Endpoint: disableUserAuth
 */
exports.disableUserAuth = onCall(
    {
      region: "asia-southeast1",
    },
    async (request) => {
      try {
        // Verify admin authentication
        if (!request.auth) {
          throw new HttpsError("unauthenticated", "Must be authenticated");
        }

        const {userId, disable} = request.data;

        if (!userId) {
          throw new HttpsError("invalid-argument", "userId is required");
        }

        const disableAuth = disable !== false; // Default to true

        // Update Firebase Auth
        await admin.auth().updateUser(userId, {
          disabled: disableAuth,
        });

        console.log(`✅ User ${userId} auth ${disableAuth ? "disabled" : "enabled"}`);

        // Log audit
        const db = admin.firestore();
        await db.collection("adminAuditLogs").add({
          action: disableAuth ? "disable_auth" : "enable_auth",
          targetUserId: userId,
          adminId: request.auth.uid,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });

        return {success: true, disabled: disableAuth};
      } catch (error) {
        console.error("❌ Error updating user auth:", error);
        throw new HttpsError("internal", error.message);
      }
    },
);


/**
 * Cloud Function: Migration - Remove legacy points fields from users
 * Endpoint: migrateUserPoints
 * 
 * This function migrates all user documents:
 * 1. Ensures currentBadge.currentPoints has the value from points/totalPoints
 * 2. Deletes the deprecated 'points' and 'totalPoints' fields
 * 
 * Usage: Call this function once after deploying the new code
 */
exports.migrateUserPoints = onCall(
    {
      region: "asia-southeast1",
    },
    async (request) => {
      try {
        // Only allow admin users to run migration
        if (!request.auth) {
          throw new HttpsError(
              "unauthenticated",
              "User must be authenticated",
          );
        }

        const db = admin.firestore();

        // Get user's role
        const callerDoc = await db.collection("users").doc(request.auth.uid).get();
        const callerRole = callerDoc.data()?.role;

        if (callerRole !== "admin") {
          throw new HttpsError(
              "permission-denied",
              "Only admins can run migration",
          );
        }

        console.log("🔄 Starting user points migration...");

        // Get all users
        const usersSnapshot = await db.collection("users").get();
        let migratedCount = 0;
        let skippedCount = 0;
        const errors = [];

        for (const userDoc of usersSnapshot.docs) {
          try {
            const data = userDoc.data();
            const userId = userDoc.id;

            // Skip if already migrated (no points/totalPoints fields)
            if (!data.points && !data.totalPoints) {
              skippedCount++;
              console.log(`⏭️ Skipped user ${userId} - already migrated`);
              continue;
            }

            // Get legacy points
            let legacyPoints = 0;
            if (data.points) {
              if (typeof data.points === "number") {
                legacyPoints = data.points;
              } else if (typeof data.points === "string") {
                legacyPoints = parseInt(data.points) || 0;
              }
            }

            // Prefer totalPoints over points
            const migratedPoints = data.totalPoints || legacyPoints;

            // Get or create currentBadge
            let currentBadge = data.currentBadge || null;

            if (currentBadge && currentBadge.currentPoints === 0 && migratedPoints !== 0) {
              // Update existing badge with migrated points
              currentBadge.currentPoints = migratedPoints;
            } else if (!currentBadge || !currentBadge.currentPoints) {
              // Create new badge with points
              currentBadge = {
                badgeId: getBadgeIdByPoints(migratedPoints),
                currentPoints: migratedPoints,
                ...getBadgeDataByPoints(migratedPoints),
              };
            }

            // Update user document
            const updateData = {
              currentBadge: currentBadge,
              level: currentBadge.level || 1,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };

            await userDoc.ref.update(updateData);

            // Remove legacy fields
            await userDoc.ref.update({
              points: admin.firestore.FieldValue.delete(),
              totalPoints: admin.firestore.FieldValue.delete(),
            });

            migratedCount++;
            console.log(`✅ Migrated user ${userId}: ${migratedPoints} points`);
          } catch (error) {
            console.error(`❌ Error migrating user ${userDoc.id}:`, error.message);
            errors.push({userId: userDoc.id, error: error.message});
          }
        }

        console.log("🎉 Migration completed!");
        console.log(`   - Migrated: ${migratedCount}`);
        console.log(`   - Skipped: ${skippedCount}`);
        console.log(`   - Errors: ${errors.length}`);

        return {
          success: true,
          migrated: migratedCount,
          skipped: skippedCount,
          errors: errors,
        };
      } catch (error) {
        console.error("❌ Error in migration:", error);
        throw new HttpsError("internal", error.message);
      }
    },
);

/**
 * Helper: Get badge ID by points
 */
function getBadgeIdByPoints(points) {
  if (points < 0) return "needs_improvement";
  if (points >= 200000) return "godlike";
  if (points >= 100000) return "grandmaster";
  if (points >= 50000) return "legend";
  if (points >= 20000) return "master";
  if (points >= 10000) return "expert";
  if (points >= 5000) return "guide";
  if (points >= 2500) return "adventurer";
  if (points >= 1000) return "traveler";
  if (points >= 500) return "explorer";
  return "newbie";
}

/**
 * Helper: Get badge data by points
 */
function getBadgeDataByPoints(points) {
  const badges = {
    needs_improvement: {
      name: "Cần cải thiện",
      description: "Hãy cố gắng đóng góp tích cực hơn",
      icon: "⚠️",
      requiredPoints: -999999,
      color: "#FF4444",
      level: 0,
    },
    newbie: {
      name: "Người mới",
      description: "Chào mừng đến với cộng đồng",
      icon: "🌱",
      requiredPoints: 0,
      color: "#A0D8B3",
      level: 1,
    },
    explorer: {
      name: "Nhà khám phá",
      description: "Bắt đầu hành trình",
      icon: "🧭",
      requiredPoints: 500,
      color: "#7FCDCD",
      level: 2,
    },
    traveler: {
      name: "Du khách",
      description: "Đang trên đường",
      icon: "🎒",
      requiredPoints: 1000,
      color: "#6FB6D9",
      level: 3,
    },
    adventurer: {
      name: "Phiêu lưu gia",
      description: "Dám thử thách",
      icon: "⛰️",
      requiredPoints: 2500,
      color: "#5B9BD5",
      level: 4,
    },
    guide: {
      name: "Hướng dẫn viên",
      description: "Chia sẻ kinh nghiệm",
      icon: "🗺️",
      requiredPoints: 5000,
      color: "#4A7BA7",
      level: 5,
    },
    expert: {
      name: "Chuyên gia",
      description: "Kiến thức sâu rộng",
      icon: "🎓",
      requiredPoints: 10000,
      color: "#3A5BA0",
      level: 6,
    },
    master: {
      name: "Bậc thầy",
      description: "Thành thạo mọi lĩnh vực",
      icon: "👑",
      requiredPoints: 20000,
      color: "#FFD700",
      level: 7,
    },
    legend: {
      name: "Huyền thoại",
      description: "Đóng góp xuất sắc",
      icon: "🏆",
      requiredPoints: 50000,
      color: "#FFA500",
      level: 8,
    },
    grandmaster: {
      name: "Đại tông sư",
      description: "Đỉnh cao du lịch",
      icon: "⭐",
      requiredPoints: 100000,
      color: "#FF6B6B",
      level: 9,
    },
    godlike: {
      name: "Thần thoại",
      description: "Huyền thoại của cộng đồng",
      icon: "💎",
      requiredPoints: 200000,
      color: "#9D4EDD",
      level: 10,
    },
  };

  const badgeId = getBadgeIdByPoints(points);
  return badges[badgeId];
}
