package com.jvisualizer.example.track;

import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Pointcut;
import org.springframework.stereotype.Component;

/**
 * Controller / Service / Repository 메서드를 AOP로 인터셉트하여
 * InvocationContext에 호출 트리를 기록합니다.
 */
@Aspect
@Component
public class TrackAspect {

    @Pointcut("within(com.jvisualizer.example.controller..*) || " +
              "within(com.jvisualizer.example.service..*) || " +
              "within(com.jvisualizer.example.repository..*)")
    public void appMethods() {}

    @Around("appMethods()")
    public Object track(ProceedingJoinPoint pjp) throws Throwable {
        InvocationContext ctx = InvocationContext.current();
        if (ctx == null) {
            return pjp.proceed(); // Filter가 시작하기 전 → 추적 안 함
        }

        String methodName = pjp.getSignature().getDeclaringTypeName()
                + "." + pjp.getSignature().getName() + "()";

        ctx.push(methodName);
        try {
            return pjp.proceed();
        } finally {
            ctx.pop();
        }
    }
}
