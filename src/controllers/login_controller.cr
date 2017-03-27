require "crypto/bcrypt"

struct UserController
  include Controller

  def login
    post_params = request.body.try(&.gets_to_end).try { |json| Hash(String, String).from_json(json) }
    return response.respond_with_error("No Body", 400) unless post_params

    username = post_params["username"]?
    password = post_params["password"]?
    return response.respond_with_error("`username` or `password` field missing", 400) unless username && password

    bcrypt_password = db.query_one? "SELECT password FROM users WHERE username = $1", username, as: String
    return response.respond_with_error("Unknown Username", 401) unless bcrypt_password
    bcrypt_password = Crypto::Bcrypt::Password.new(bcrypt_password)

    if bcrypt_password == password
      # Auth Success
      token = SecureRandom.hex
      db.exec "UPDATE users SET tokens = array_append(tokens, $1) WHERE username = $2", token, username

      response.headers["Access-Control-Allow-Origin"] = "*"
      response.content_type = "application/json"
      {token: token}.to_json(response)
    else
      response.respond_with_error("Incorrect Password", 401)
    end
  end

  def logout
    token = check_token
    return response.respond_with_error("Not Logged In", 401) unless token

    db.exec("UPDATE users SET tokens = array_remove(tokens, $1) WHERE username = (
      SELECT username FROM users WHERE tokens @> ARRAY[$1]
    )", token)

    raise "Assertion Failed" if check_token
  end

  def register
    post_params = request.body.try(&.gets_to_end).try { |json| Hash(String, String).from_json(json) }
    return response.respond_with_error("No Body", 400) unless post_params

    username = post_params["username"]?
    password = post_params["password"]?
    return response.respond_with_error("`username` or `password` field missing", 400) unless username && password

    bcrypt_password = Crypto::Bcrypt::Password.create(password)
    token = SecureRandom.hex

    db.exec "INSERT INTO users (username, password, tokens) VALUES ($1, $2, $3)", username, bcrypt_password, [token]

    response.headers["Access-Control-Allow-Origin"] = "*"
    response.content_type = "application/json"
    {token: token}.to_json(response)
  end
end
