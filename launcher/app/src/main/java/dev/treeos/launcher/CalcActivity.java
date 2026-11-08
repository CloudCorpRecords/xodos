package dev.treeos.launcher;

import android.app.Activity;
import android.graphics.Color;
import android.os.Bundle;
import android.view.Gravity;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.GridLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;

/**
 * TreeOS Calculator — real arithmetic with a safe hand-written parser
 * (tokenizer + shunting-yard; no eval, no scripting engine).
 * Supports + − × ÷, parentheses, decimals, unary minus, implicit multiplication.
 */
public class CalcActivity extends Activity {

    private TextView display;
    private final StringBuilder expr = new StringBuilder();
    private boolean justEvaluated = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        LinearLayout root = Ui.root(this);
        root.addView(Ui.title(this, "🧮 Calculator"));

        display = new TextView(this);
        display.setText("0");
        display.setTextColor(Color.WHITE);
        display.setTextSize(36);
        display.setGravity(Gravity.END | Gravity.CENTER_VERTICAL);
        display.setBackgroundColor(Ui.PANEL);
        display.setPadding(24, 24, 24, 24);
        LinearLayout.LayoutParams dp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        dp.setMargins(0, 0, 0, 20);
        display.setLayoutParams(dp);
        root.addView(display);

        GridLayout grid = new GridLayout(this);
        grid.setColumnCount(4);
        String[] keys = {
                "C", "(", ")", "⌫",
                "7", "8", "9", "÷",
                "4", "5", "6", "×",
                "1", "2", "3", "−",
                "0", ".", "=", "+"
        };
        for (String k : keys) {
            Button b = Ui.button(this, k);
            GridLayout.LayoutParams lp = new GridLayout.LayoutParams();
            lp.width = 0;
            lp.height = ViewGroup.LayoutParams.WRAP_CONTENT;
            lp.columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f);
            lp.setMargins(6, 6, 6, 6);
            b.setLayoutParams(lp);
            b.setOnClickListener(v -> onKey(k));
            grid.addView(b);
        }
        root.addView(grid);
        setContentView(root);
    }

    private void onKey(String k) {
        switch (k) {
            case "C":
                expr.setLength(0);
                break;
            case "⌫":
                if (expr.length() > 0) expr.deleteCharAt(expr.length() - 1);
                break;
            case "=":
                evaluate();
                return;
            default:
                if (justEvaluated && (isDigit(k) || k.equals(".") || k.equals("("))) {
                    expr.setLength(0);
                }
                expr.append(k);
        }
        justEvaluated = false;
        display.setText(expr.length() == 0 ? "0" : expr.toString());
    }

    private boolean isDigit(String k) {
        return k.length() == 1 && Character.isDigit(k.charAt(0));
    }

    private void evaluate() {
        String s = expr.toString();
        try {
            double v = Parser.eval(s);
            String out = format(v);
            display.setText(out);
            expr.setLength(0);
            expr.append(out);
            justEvaluated = true;
        } catch (ArithmeticException e) {
            display.setText("Can't divide by 0");
            expr.setLength(0);
            justEvaluated = false;
        } catch (Exception e) {
            display.setText("Error");
            expr.setLength(0);
            justEvaluated = false;
        }
    }

    static String format(double v) {
        if (v == Math.rint(v) && Math.abs(v) < 1e15) return Long.toString((long) v);
        return Double.toString(v);
    }

    /** Safe expression evaluator: tokenizer + shunting-yard to RPN, then stack eval. */
    static final class Parser {
        static double eval(String s) {
            List<Object> tokens = tokenize(s);
            List<Object> rpn = toRpn(tokens);
            Deque<Double> stack = new ArrayDeque<>();
            for (Object t : rpn) {
                if (t instanceof Double) {
                    stack.push((Double) t);
                } else {
                    char op = (Character) t;
                    if (op == 'u') { // unary minus
                        if (stack.isEmpty()) throw new IllegalArgumentException("bad unary");
                        stack.push(-stack.pop());
                    } else {
                        if (stack.size() < 2) throw new IllegalArgumentException("bad expr");
                        double b = stack.pop(), a = stack.pop();
                        switch (op) {
                            case '+': stack.push(a + b); break;
                            case '−': stack.push(a - b); break;
                            case '×': stack.push(a * b); break;
                            case '÷':
                                if (b == 0.0) throw new ArithmeticException("div0");
                                stack.push(a / b); break;
                            default: throw new IllegalArgumentException("bad op");
                        }
                    }
                }
            }
            if (stack.size() != 1) throw new IllegalArgumentException("bad expr");
            return stack.pop();
        }

        private static List<Object> tokenize(String s) {
            List<Object> out = new ArrayList<>();
            int i = 0;
            boolean expectOperand = true;
            while (i < s.length()) {
                char c = s.charAt(i);
                if (Character.isDigit(c) || c == '.') {
                    int j = i;
                    while (j < s.length() && (Character.isDigit(s.charAt(j)) || s.charAt(j) == '.')) j++;
                    out.add(Double.parseDouble(s.substring(i, j)));
                    i = j;
                    expectOperand = false;
                } else if (c == '(') {
                    if (!expectOperand) { out.add('×'); } // implicit multiply: 2(3)
                    out.add('(');
                    i++;
                    expectOperand = true;
                } else if (c == ')') {
                    out.add(')');
                    i++;
                    expectOperand = false;
                } else if (c == '+' || c == '−' || c == '×' || c == '÷' || c == '-') {
                    char op = (c == '-') ? '−' : c;
                    if (expectOperand && op == '−') {
                        out.add('u'); // unary minus marker, handled as pseudo-op below
                        // Represent unary minus as 0 - x would change precedence; use 'u' token in RPN step
                        out.set(out.size() - 1, 'u');
                        i++;
                        // still expecting operand
                    } else {
                        out.add(op);
                        i++;
                        expectOperand = true;
                    }
                } else {
                    throw new IllegalArgumentException("bad char " + c);
                }
            }
            return out;
        }

        private static int prec(char op) {
            switch (op) {
                case 'u': return 3;
                case '×': case '÷': return 2;
                case '+': case '−': return 1;
                default: return 0;
            }
        }

        private static List<Object> toRpn(List<Object> tokens) {
            List<Object> out = new ArrayList<>();
            Deque<Character> ops = new ArrayDeque<>();
            for (Object t : tokens) {
                if (t instanceof Double) {
                    out.add(t);
                } else {
                    char c = (Character) t;
                    if (c == '(') {
                        ops.push(c);
                    } else if (c == ')') {
                        boolean found = false;
                        while (!ops.isEmpty()) {
                            char top = ops.pop();
                            if (top == '(') { found = true; break; }
                            out.add(top);
                        }
                        if (!found) throw new IllegalArgumentException("mismatched parens");
                    } else { // operator incl. unary 'u' (right-assoc, highest prec)
                        while (!ops.isEmpty() && ops.peek() != '('
                                && (prec(ops.peek()) > prec(c) || (prec(ops.peek()) == prec(c) && c != 'u'))) {
                            out.add(ops.pop());
                        }
                        ops.push(c);
                    }
                }
            }
            while (!ops.isEmpty()) {
                char top = ops.pop();
                if (top == '(') throw new IllegalArgumentException("mismatched parens");
                out.add(top);
            }
            return out;
        }
    }
}
