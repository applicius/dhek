package dhek

import scala.concurrent.duration.Duration

case class Settings(secretKey: Array[Char], timeout: Duration)