package dhek

import javax.servlet.http.HttpServletRequest

object Extractor {
  object & {
    def unapply[A](a: A) = Some(a, a)
  }

  object GET {
    def unapply(req: HttpServletRequest) = req.getMethod match {
      case "GET" ⇒ Some(req)
      case _     ⇒ None
    }
  }

  object POST {
    def unapply(req: HttpServletRequest) = req.getMethod match {
      case "POST" ⇒ Some(req)
      case _      ⇒ None
    }
  }

  object Path {
    def unapply(req: HttpServletRequest) = Option(req.getRequestURI)
  }

  case class Attr(name: String) {
    def unapply(r: HttpServletRequest) = Option(r getAttribute name)
  }

  case class Param(name: String) {
    def unapply(r: HttpServletRequest) = Option(r getParameter name)
  }

  case class Params(name: String) {
    def unapply(r: HttpServletRequest) =
      Option(r.getParameterValues(name)).map(_.toList)
  }
}
